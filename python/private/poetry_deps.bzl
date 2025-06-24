load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@ofiuco_defs//:defs.bzl", _python_host_runtime = "python_host_runtime", _python_toolchain_prefix = "python_toolchain_prefix", _python_version = "python_version")
load("@rules_python//python:defs.bzl", "PyInfo", "PyRuntimeInfo")
load("@rules_python//python:versions.bzl", _MINOR_MAPPING = "MINOR_MAPPING")
load("//python:markers.bzl", "evaluate", "parse")

# Environment Markers https://peps.python.org/pep-0508/#environment-markers
#
# Platform tags https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#platform-tag
#
# Order of platform tags is used to resolve ambiguity in pip as valid tags order defined in
# [TargetPython.get_sorted_tags](https://github.com/pypa/pip/blob/0827d76b/src/pip/_internal/models/target_python.py#L104-L110)
# is used as a priority map for found packages in a
# [CandidateEvaluator._sort_key](https://github.com/pypa/pip/blob/0827d76b/src/pip/_internal/index/package_finder.py#L529-L533)
# of CandidateEvaluator.compute_best_candidate.
DEFAULT_PLATFORMS = {
    "aarch64-apple-darwin": """{"os_name": "posix", "platform_machine": "arm64", "platform_system": "Darwin", "platform_tags": ["macosx_11_0_arm64", "macosx_12_0_arm64", "macosx_13_0_arm64", "macosx_14_0_arm64"], "sys_platform": "darwin"}""",

    "aarch64-unknown-linux-gnu": """{"os_name": "posix", "platform_machine": "arm64", "platform_system": "Linux", "platform_tags": ["manylinux_2_17_arm64", "manylinux_2_17_aarch64", "manylinux_2_27_aarch64", "manylinux_2_28_aarch64"], "sys_platform": "linux"}""",

    "x86_64-apple-darwin": """{"os_name": "posix", "platform_machine": "x86_64", "platform_system": "Darwin", "platform_tags": ["macosx_10_13_x86_64", "macosx_10_15_x86_64"], "sys_platform": "darwin"}""",

    "x86_64-pc-windows-msvc": """{"os_name": "nt", "platform_machine": "x86_64", "platform_system": "Windows", "platform_tags": ["win_amd64"], "sys_platform": "win32"}""",

    "x86_64-unknown-linux-gnu": """{"os_name": "posix", "platform_machine": "x86_64", "platform_system": "Linux", "platform_tags": ["linux_x86_64", "manylinux2014_x86_64", "manylinux_2_12_x86_64", "manylinux_2_17_x86_64", "manylinux_2_27_x86_64", "manylinux_2_28_x86_64"], "sys_platform": "linux"}""",

    "x86_64-unknown-linux-musl": """{"os_name": "posix", "platform_machine": "x86_64", "platform_system": "Linux", "platform_tags": ["musllinux_1_2_x86_64"], "sys_platform": "linux"}""",
}

def _get_python_version(interpreter):
    parts = interpreter.replace(".", "_").split(_python_toolchain_prefix.replace(".", "_"))
    for part in parts:
        tokens = [token for token in part.split("_") if token]
        for index in range(len(tokens)):
            if not tokens[index].isdigit():
                break
        version = ".".join(tokens[:index])
        if version:
            return version

    return _python_version

def derive_environment_markers(interpreter, interpreter_markers, host_tags):
    python_version = _get_python_version(interpreter)
    for fr, to in interpreter_markers.items():
        if fr in interpreter:
            tags = {
                "extra": "*",
                "implementation_name": "cpython",
                "platform_python_implementation": "CPython",
                "platform_tags": [],
                "python_version": python_version,
                "python_full_version": _MINOR_MAPPING.get(python_version, python_version),
                "interpreter": interpreter,
            }
            tags.update(**json.decode(to))
            return fr, tags

    return "host", json.decode(host_tags)

def include_dep(dep, markers, environment):
    if not markers:
        return True
    markers = json.decode(markers)
    if dep.label.name not in markers:
        return True

    marker = markers[dep.label.name]
    return evaluate(parse(marker, environment))

def get_imports(target):
    return target[PyInfo].imports if PyInfo in target else depset()

def get_transitive_sources(target):
    return target[PyInfo].transitive_sources if PyInfo in target else depset()

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
    runtime_tag, tags = derive_environment_markers(py_runtime_info.interpreter.path, ctx.attr.platforms, ctx.attr.system_platform)
    python_version = tags["python_version"]
    platform_tags = tags["platform_tags"]

    if not ctx.attr.constraint:
        # Virtual package does not require installation and only by-passes selected transitive dependencies
        deps = [dep for dep in ctx.attr.deps if include_dep(dep, ctx.attr.markers, tags)]
        transitive_imports = [get_imports(dep) for dep in deps]
        transitive_depsets = [get_transitive_sources(dep) for dep in deps]
        files = depset(transitive = transitive_depsets)
        imports = depset([], transitive = transitive_imports)
        return [
            DefaultInfo(runfiles = ctx.runfiles(transitive_files = files)),
            PyInfo(transitive_sources = files, imports = imports),
        ]

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
    arguments += ["--source={}".format(ctx.attr.source)] if ctx.attr.source else []
    arguments += ["--develop"] if ctx.attr.develop else []

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
    deps = [dep for dep in ctx.attr.deps if include_dep(dep, ctx.attr.markers, tags)]
    transitive_imports = [get_imports(dep) for dep in deps]
    transitive_depsets = [get_transitive_sources(dep) for dep in deps]
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
        "constraint": attr.string(doc = "The package version constraint string"),
        "deps": attr.label_list(doc = "The package dependencies list"),
        "description": attr.string(doc = "The package description"),
        "files": attr.string_dict(doc = "The package resolved files"),
        "source": attr.string(doc = "The source JSON struct"),
        "develop": attr.bool(),
        "markers": attr.string(doc = "The JSON string with a dictionary of dependency markers accordingly to PEP 508"),
        "platforms": attr.string_dict(
            default = DEFAULT_PLATFORMS,
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
