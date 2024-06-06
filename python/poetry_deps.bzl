load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("@rules_python//python:defs.bzl", StarPyInfo = "PyInfo")
load("//python/private:poetry_deps.bzl", _derive_environment_markers = "derive_environment_markers", _include_dep = "include_dep")
load("//python/private:poetry_deps.bzl", _get_imports = "get_imports", _get_transitive_sources = "get_transitive_sources")
load("//python/private:poetry_deps.bzl", _DEFAULT_PLATFORMS = "DEFAULT_PLATFORMS")

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
    runtime_tag, tags = _derive_environment_markers(py_runtime_info.interpreter.path, ctx.attr.platforms)
    python_version = tags["python_version"]
    platform_tags = tags["platform_tags"]

    # Get Python tooling toolchain and runfiles dependencies
    poetry_deps_info = ctx.attr._poetry_deps[DefaultInfo]
    poetry_deps_binary = poetry_deps_info.files_to_run.executable
    poetry_deps_runfiles = poetry_deps_info.default_runfiles.files
    poetry_deps_python = [x for x in poetry_deps_runfiles.to_list() if x.path.endswith("bin/python3")].pop()
    _, input_manifests = ctx.resolve_tools(tools = [ctx.attr._poetry_deps])

    # Declare package output directory
    output = ctx.actions.declare_directory("{}/{}/{}".format(python_version, runtime_tag, ctx.label.name))

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
    ]
    arguments += ["--source_url={}".format(url) for url in ctx.attr.source_urls]
    arguments += ["--index={}".format(url) for url in ctx.attr.extra_index_urls]

    for platform in platform_tags:
        arguments += ["--platform", platform]

    # Get CC target toolchain and propagate to the installation script
    cc_toolchain_files = depset()
    cc_toolchain = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"]
    if cc_toolchain and hasattr(cc_toolchain, "cc"):
        cc = cc_toolchain.cc
        cc_toolchain_files = cc.all_files
        arguments.append("--cc_toolchain=" + json.encode({
            "~AR": cc.ar_executable,
            "~CC": cc.compiler_executable,
            " CFLAGS": " ".join(["-I{}".format(dir) for dir in cc.built_in_include_directories]),
            "~GCOV": cc.gcov_executable,
            "~LD": cc.ld_executable,
            " LDFLAGS": "-Wl,-rpath,{}".format(cc.dynamic_runtime_solib_dir),
            "~NM": cc.nm_executable,
            "~OBJCOPY": cc.objcopy_executable,
            "~OBJDUMP": cc.objdump_executable,
            "~CPP": cc.preprocessor_executable,
            "~STRIP": cc.strip_executable,
            "sysroot": str(cc.sysroot),
            "target_gnu_system_name": cc.target_gnu_system_name,
            "toolchain_id": cc.toolchain_id,
        }))

    # Run wheel installation
    ctx.actions.run(
        outputs = [output],
        inputs = poetry_deps_info.files,
        mnemonic = "InstallWheel",
        progress_message = "Installing package {} ({}) for Python {} {}".format(ctx.label.name, ctx.attr.constraint, python_version, runtime_tag),
        arguments = arguments,
        use_default_shell_env = True,
        input_manifests = input_manifests,
        executable = poetry_deps_python,
        tools = poetry_deps_runfiles,
        execution_requirements = {"requires-network": ""},
    )

    # Create output information providers
    # NOTE: keep built-in till [PyInfo](https://github.com/bazelbuild/bazel/blob/d7cf0048/src/main/java/com/google/devtools/build/lib/starlarkbuildapi/python/PyInfoApi.java#L31)
    # is used in the upstream code
    deps = [dep for dep in ctx.attr.deps if _include_dep(dep, ctx.attr.markers, tags)]
    transitive_imports = [_get_imports(dep) for dep in deps]
    transitive_depsets = [_get_transitive_sources(dep) for dep in deps]
    runfiles = [output] + [item for dep in transitive_depsets for item in dep.to_list()]
    files = depset([output], transitive = transitive_depsets)
    imports = depset([output.short_path.replace("../", "")], transitive = transitive_imports)
    return [
        DefaultInfo(files = files, runfiles = ctx.runfiles(files = runfiles)),
        PyInfo(transitive_sources = files, imports = imports),
        StarPyInfo(transitive_sources = files, imports = imports),
    ]

package = rule(
    implementation = _package_impl,
    provides = [PyInfo, StarPyInfo],
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
        "_poetry_deps": attr.label(default = ":poetry_deps", cfg = "exec", executable = True),
    },
    toolchains = [
        "@bazel_tools//tools/python:toolchain_type",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)
