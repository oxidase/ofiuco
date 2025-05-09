load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@ofiuco_defs//:defs.bzl", _python_host_runtime = "python_host_runtime")
load("@rules_python//python:defs.bzl", "PyInfo", "PyRuntimeInfo")
load("//python/private:poetry_deps.bzl", _DEFAULT_PLATFORMS = "DEFAULT_PLATFORMS", _derive_environment_markers = "derive_environment_markers", _get_imports = "get_imports", _get_transitive_sources = "get_transitive_sources", _include_dep = "include_dep")

PYTHON_BINARY = ["bin/python3", "python/py3wrapper.sh"]

def get_tool(ctx, cc_toolchain, feature_configuration, action_name):
    binary = cc_common.get_tool_for_action(feature_configuration = feature_configuration, action_name = action_name)
    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = cc_common.create_compile_variables(
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            include_directories = depset(direct = cc_toolchain.built_in_include_directories),
            user_compile_flags = ctx.attr.copts if hasattr(ctx.attr, "copts") else [],
            use_pic = True,
        ),
    )
    return binary, flags

def _package_impl(ctx):
    """
    Rule to install a Python package.

    Arguments:
        ctx: The rule context.

    Attributes:
        deps: label_list The package dependencies list.
        markers: string The JSON string with markers accordingly to PEP 508 – Dependency specification for Python Software Packages.

    Private attributes:
        _poetry_deps:

    Returns:
        The providers list or a tuple with a Poetry package.

    Required toolchains:
         @bazel_tools//tools/python:toolchain_type
    """

    # Get Python target toolchain and corresponding tags
    py_toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    py_runtime_info = py_toolchain.py3_runtime
    runtime_tag, tags = _derive_environment_markers(py_runtime_info.interpreter.path, ctx.attr.platforms, ctx.attr.system_platform)
    python_version = tags["python_version"]
    platform_tags = tags["platform_tags"]

    # Get Python tooling toolchain and runfiles dependencies
    poetry_deps_info = ctx.attr._poetry_deps[DefaultInfo]
    poetry_deps_binary = poetry_deps_info.files_to_run.executable
    poetry_deps_runfiles = poetry_deps_info.default_runfiles.files
    poetry_deps_runtime_info = ctx.attr._python_host[PyRuntimeInfo]

    install_inputs = depset(transitive = [poetry_deps_info.files, poetry_deps_runtime_info.files])

    # Declare package output directory
    output = ctx.actions.declare_directory("{}/{}/{}".format(python_version, runtime_tag, ctx.label.name))
    entry_points = ctx.actions.declare_file("{}/{}/.dist-info/{}/entry_points.txt".format(python_version, runtime_tag, ctx.label.name))

    # Collect installation tool arguments
    arguments = [
        "-B",
        poetry_deps_binary.path,
        "install",
        ctx.attr.constraint,
        output.path,
        "--files",
        json.encode(ctx.attr.files),
        "--python_version",
        python_version,
        "--entry_points",
        entry_points.path,
    ]
    arguments += ["--source_url={}".format(url) for url in ctx.attr.source_urls]
    arguments += ["--index={}".format(url) for url in ctx.attr.extra_index_urls]

    for platform in platform_tags:
        arguments += ["--platform", platform]

    # Get CC target toolchain and propagate to the installation script
    cc_toolchain = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"]
    if cc_toolchain and hasattr(cc_toolchain, "cc") and type(cc_toolchain.cc) != "string":
        cc = cc_toolchain.cc
        feature_configuration = cc_common.configure_features(
            ctx = ctx,
            cc_toolchain = cc,
            requested_features = ctx.features,
            unsupported_features = ctx.disabled_features,
        )
        cc_attr = {k: getattr(cc, k) for k in dir(cc) if type(getattr(cc, k)) == "string" or
                                                         type(getattr(cc, k)) == "File"}
        cc_attr = {k: v.path if type(v) == "File" else v for k, v in cc_attr.items()}
        cc_attr["AS"], cc_attr["ASFLAGS"] = get_tool(ctx, cc, feature_configuration, ACTION_NAMES.assemble)
        cc_attr["CC"], cc_attr["CFLAGS"] = get_tool(ctx, cc, feature_configuration, ACTION_NAMES.c_compile)
        cc_attr["CXX"], cc_attr["CXXFLAGS"] = get_tool(ctx, cc, feature_configuration, ACTION_NAMES.cpp_compile)
        cc_attr["LD"], cc_attr["LDFLAGS"] = get_tool(ctx, cc, feature_configuration, ACTION_NAMES.cpp_link_dynamic_library)
        arguments.append("--cc_toolchain=" + json.encode(cc_attr))

        install_inputs = depset(transitive = [install_inputs, cc.all_files])

    # Run wheel installation
    ctx.actions.run(
        outputs = [output, entry_points],
        inputs = install_inputs,
        mnemonic = "InstallWheel",
        progress_message = "Installing package {} ({}) for Python {} {}".format(ctx.label.name, ctx.attr.constraint, python_version, runtime_tag),
        arguments = arguments,
        use_default_shell_env = True,
        executable = poetry_deps_runtime_info.interpreter.path,
        tools = poetry_deps_runfiles,
        execution_requirements = {"requires-network": ""},
    )

    # Create output information providers
    deps = [dep for dep in ctx.attr.deps if _include_dep(dep, ctx.attr.markers, tags)]
    transitive_imports = [_get_imports(dep) for dep in deps]
    transitive_depsets = [_get_transitive_sources(dep) for dep in deps]
    files = depset([output], transitive = transitive_depsets)
    imports = depset([output.short_path.replace("../", "")], transitive = transitive_imports)
    return [
        DefaultInfo(files = depset([output, entry_points]), runfiles = ctx.runfiles(transitive_files = files)),
        PyInfo(transitive_sources = files, imports = imports),
    ]

package = rule(
    implementation = _package_impl,
    provides = [PyInfo],
    attrs = {
        "constraint": attr.string(mandatory = True, doc = "The package version constraint string"),
        "deps": attr.label_list(doc = "The package dependencies list"),
        "description": attr.string(doc = "The package description"),
        "files": attr.string_dict(doc = "The package resolved files"),
        "source_urls": attr.string_list(doc = "The source file URLs"),
        "extra_index_urls": attr.string_list(doc = "The extra repository index"),
        "markers": attr.string(doc = "The JSON string with a dictionary of dependency markers accordingly to PEP 508"),
        "platforms": attr.string_dict(
            default = _DEFAULT_PLATFORMS,
            doc = "The mapping of an interpter substring mapping to environment markers and platform tags as a JSON string. " +
                  "Default value corresponds to platforms defined at " +
                  "https://github.com/bazelbuild/rules_python/blob/23cf6b66/python/versions.bzl#L231-L277",
        ),
        "system_platform": attr.string(doc = "The system platform environment markers as a JSON string"),
        "_poetry_deps": attr.label(default = ":poetry_deps", cfg = "exec", executable = True),
        "_python_host": attr.label(default = _python_host_runtime),
    },
    toolchains = [
        "@bazel_tools//tools/python:toolchain_type",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    fragments = ["cpp"],
)
