load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@ofiuco_defs//:defs.bzl", _python_host_runtime = "python_host_runtime", _python_toolchain_prefix = "python_toolchain_prefix", _python_version = "python_version")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
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

def _format_library_link(lib):
    return "-L$PWD/{} -l{}".format(paths.dirname(lib), paths.split_extension(paths.basename(lib))[0].removeprefix("lib"))

def _package_impl(ctx):
    """
    Rule to install a Python package.

    Arguments:
        ctx: The rule context.

    Attributes:
        deps: label_list The package dependencies list.
        markers: string The JSON string with markers accordingly to PEP 508 – Dependency specification for Python Software Packages.

    Private attributes:
        _package_deps:

    Returns:
        The providers list or a tuple with a Python package.

    Required toolchains:
         @bazel_tools//tools/python:toolchain_type
    """

    # Get Python target toolchain and corresponding tags
    py_toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    py_runtime_info = py_toolchain.py3_runtime
    runtime_tag, tags = derive_environment_markers(py_runtime_info.interpreter.path, ctx.attr.platforms, ctx.attr.system_platform)
    python_version = tags["python_version"]
    platform_tags = tags["platform_tags"]

    # Get package files
    package_files = ctx.attr.package.files.to_list() if ctx.attr.package else []
    package_import, output_files = [], package_files

    # Find the package build file and update package import and directory
    if package_files:
        package_build_files = [file for file in package_files if paths.basename(file.path).endswith("BUILD.bazel")]
        package_build_file = sorted(package_build_files, reverse=True).pop()
        package_import = [paths.dirname(package_build_file.short_path).replace("../", "")]
        package_directory = paths.dirname(package_build_file.path)

    # Call "pip install" for the sdist or local packages
    if ctx.attr.package and ctx.attr.package.label.name in ["pkg", "sdist"]:
        # Get Python tooling toolchain and runfiles dependencies
        package_deps_info = ctx.attr._package_deps[DefaultInfo]
        package_deps_binary = package_deps_info.files_to_run.executable
        package_deps_runfiles = package_deps_info.default_runfiles.files
        package_deps_runtime_info = ctx.attr._python_host[PyRuntimeInfo]

        build_transitive_deps = [py_runtime_info.files, package_deps_info.files, package_deps_runtime_info.files]

        # Declare package output directory
        output = ctx.actions.declare_directory("{}/{}/{}".format(python_version, runtime_tag, ctx.label.name))
        package_import = [output.short_path.replace("../", "")]
        entry_points = ctx.actions.declare_file("{}/{}/.dist-info/{}/entry_points.txt".format(python_version, runtime_tag, ctx.label.name))
        output_files = [output, entry_points]

        # Collect installation tool arguments
        arguments = [
            "-B",
            package_deps_binary.path,
            "install",
            package_directory,
            output.path,
            "--python_version",
            python_version,
            "--entry_points",
            entry_points.path,
        ]
        arguments += ["--develop"] if ctx.attr.develop else []

        for platform in platform_tags:
            arguments += ["--platform", platform]


        # Get CC target toolchain and propagate to the installation script
        cc_toolchain = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"]
        if cc_toolchain and hasattr(cc_toolchain, "cc") and type(cc_toolchain.cc) != "string":
            # Toolchain deps
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

            cc_attr["AR"], cc_attr["ARFLAGS"] = get_tool(ctx, cc, feature_configuration, ACTION_NAMES.cpp_link_static_library)
            if not cc_attr["ARFLAGS"]:
                if cc_attr["AR"].endswith("libtool"):
                    cc_attr["ARFLAGS"] = ["-static", "-o"]
                elif cc_attr["AR"].endswith("ar"):
                    cc_attr["ARFLAGS"] =  ["rcs"]

            # CcInfo dependencies
            cc_deps = [dep for dep in ctx.attr.deps if CcInfo in dep] + ctx.attr._libpython

            # Compilation context
            cc_deps_headers = [dep[CcInfo].compilation_context.headers for dep in cc_deps]
            cc_deps_cflags = \
                ["-I$PWD/{}".format(path) for dep in cc_deps for path in dep[CcInfo].compilation_context.includes.to_list()] + \
                ["-I$PWD/{}".format(path) for dep in cc_deps for path in dep[CcInfo].compilation_context.framework_includes.to_list()] + \
                ["-I$PWD/{}".format(path) for dep in cc_deps for path in dep[CcInfo].compilation_context.framework_includes.to_list()] + \
                ["-iquote $PWD/{}".format(path) for dep in cc_deps for path in dep[CcInfo].compilation_context.quote_includes.to_list()] + \
                ["-isystem $PWD/{}".format(path) for dep in cc_deps for path in dep[CcInfo].compilation_context.system_includes.to_list()] + \
                ["-D{}".format(define) for dep in cc_deps for define in dep[CcInfo].compilation_context.defines.to_list()]

            # Linking context
            cc_deps_linker_inputs = depset(transitive = [dep[CcInfo].linking_context.linker_inputs for dep in cc_deps], order = "topological")
            cc_deps_libraries =[lib.dynamic_library or lib.static_library for inputs in cc_deps_linker_inputs.to_list() for lib in inputs.libraries]
            cc_deps_ldflags = ["-Wl,-rpath,{} -L$PWD/{} $PWD/{}".format(paths.dirname(file.short_path), paths.dirname(file.path), file.path) for file in cc_deps_libraries if file]
            output_files += cc_deps_libraries

            # Add to flags tranitive dependencies
            cc_attr["CFLAGS"] = cc_attr["CFLAGS"] + cc_deps_cflags
            cc_attr["CXXFLAGS"] = cc_attr["CXXFLAGS"] + cc_deps_cflags
            cc_attr["LDFLAGS"] = cc_attr["LDFLAGS"] + cc_deps_ldflags

            build_transitive_deps += [depset(cc_deps_libraries, transitive = [cc.all_files] + cc_deps_headers)]

            # Generates CC toolchain argument
            arguments.append("--cc_toolchain=" + json.encode(cc_attr))

        # Get Rust target toolchain and propagate to the installation script
        rust_toolchain = ctx.toolchains["@rules_rust//rust:toolchain_type"]
        if rust_toolchain:
            # Generates Rust toolchain argument
            arguments.append("--rust_toolchain=" + json.encode(rust_toolchain.make_variables.variables))

            build_transitive_deps += [depset(transitive = [rust_toolchain.all_files])]

        # Pack transitive depenedencies
        inputs = depset(package_files, transitive = build_transitive_deps)

        # Execution requirements
        execution_requirements = {
            "requires-network": "",  # required for build environment setup
        }

        # Run package build and install
        ctx.actions.run(
            outputs = [output, entry_points],
            inputs = inputs,
            mnemonic = "InstallWheel",
            progress_message = "Installing package {} for Python {} {}".format(ctx.label.name, python_version, runtime_tag),
            arguments = arguments,
            use_default_shell_env = True,
            executable = package_deps_runtime_info.interpreter.path,
            tools = package_deps_runfiles,
            execution_requirements = execution_requirements,
        )

    # Create output information providers CcInfo and PyInfo
    deps = [dep for dep in ctx.attr.deps if include_dep(dep, ctx.attr.markers, tags)]

    # PyInfo
    transitive_imports = [get_imports(dep) for dep in deps]
    transitive_depsets = [get_transitive_sources(dep) for dep in deps]
    files = depset(direct=output_files, transitive = transitive_depsets + [py_runtime_info.files])
    imports = depset(direct = package_import, transitive = transitive_imports)

    # CcInfo
    compilation_context = cc_common.create_compilation_context(
        defines = depset([
            'PYTHON_PROGRAM_NAME=L"{}"'.format(py_runtime_info.interpreter.short_path),
            'PYTHON_PATH=L"{}"'.format(":".join(["../" + path for path in imports.to_list()]))
        ])
    )

    return [
        DefaultInfo(files = depset(output_files), runfiles = ctx.runfiles(transitive_files = files)),
        CcInfo(compilation_context = compilation_context),
        PyInfo(transitive_sources = files, imports = imports),
    ]



package = rule(
    implementation = _package_impl,
    provides = [PyInfo],
    attrs = {
        "deps": attr.label_list(doc = "The package dependencies list"),
        "data": attr.label_list(doc = "The package dependencies list"),
        "description": attr.string(doc = "The package description"),
        "package": attr.label(doc = "The Python package target"),
        "develop": attr.bool(),
        "markers": attr.string(doc = "The JSON string with a dictionary of dependency markers accordingly to PEP 508"),
        "platforms": attr.string_dict(
            default = DEFAULT_PLATFORMS,
            doc = "The mapping of an interpter substring mapping to environment markers and platform tags as a JSON string. " +
                  "Default value corresponds to platforms defined at " +
                  "https://github.com/bazelbuild/rules_python/blob/23cf6b66/python/versions.bzl#L231-L277",
        ),
        "system_platform": attr.string(doc = "The system platform environment markers as a JSON string"),
        "_libpython": attr.label_list(default = [
            "@rules_python//python/cc:current_py_cc_headers",
            "@rules_python//python/cc:current_py_cc_libs",
        ]),
        "_package_deps": attr.label(default = ":package_deps", cfg = "exec", executable = True),
        "_python_host": attr.label(default = _python_host_runtime),
    },
    toolchains = [
        "@bazel_tools//tools/python:toolchain_type",
        config_common.toolchain_type("@bazel_tools//tools/cpp:toolchain_type", mandatory = False),
        config_common.toolchain_type("@rules_rust//rust:toolchain_type", mandatory = False),
    ],
    fragments = ["cpp"],
)
