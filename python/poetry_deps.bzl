load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
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
_DEFAULT_PLATFORMS = {
    "aarch64-apple-darwin": """{"os_name": "posix", "platform_machine": "arm64", "platform_system": "Darwin", "platform_tags": ["macosx_11_0_arm64", "macosx_12_0_arm64", "macosx_13_0_arm64", "macosx_14_0_arm64"], "sys_platform": "darwin"}""",
    "aarch64-unknown-linux-gnu": """{"os_name": "posix", "platform_machine": "arm64", "platform_system": "Linux", "platform_tags": ["manylinux_2_17_arm64", "manylinux_2_17_aarch64"], "sys_platform": "linux"}""",
    "x86_64-apple-darwin": """{"os_name": "posix", "platform_machine": "x86_64", "platform_system": "Darwin", "platform_tags": ["macosx_10_15_x86_64"], "sys_platform": "darwin"}""",
    "x86_64-pc-windows-msvc": """{"os_name": "nt", "platform_machine": "x86_64", "platform_system": "Windows", "platform_tags": ["win_amd64"], "sys_platform": "win32"}""",
    "x86_64-unknown-linux-gnu": """{"os_name": "posix", "platform_machine": "x86_64", "platform_system": "Linux", "platform_tags": ["linux_x86_64", "manylinux2014_x86_64", "manylinux_2_12_x86_64", "manylinux_2_17_x86_64", "manylinux_2_27_x86_64", "manylinux_2_28_x86_64"], "sys_platform": "linux"}""",
}

def _collect_version(parts):
    version = []
    for index in range(len(parts)):
        if not parts[index].isdigit():
            break

        version.append(parts[index])

    return ".".join(version)

def _get_python_version(interpreter):
    parts = interpreter.split("_")
    for index in range(len(parts)):
        if parts[index].endswith("python3"):
            return "3." + _collect_version(parts[index + 1:])
        elif parts[index].endswith("python"):
            return _collect_version(parts[index + 1:])

    return "3"

def _derive_environment_markers(interpreter, interpreter_markers):
    tags = {
        "extra": "*",
        "implementation_name": "cpython",
        "platform_python_implementation": "CPython",
        "platform_tags": [],
        "python_version": _get_python_version(interpreter),
        "interpreter": interpreter,
    }

    for fr, to in interpreter_markers.items():
        if fr in interpreter:
            tags.update(**json.decode(to))
            return fr, tags

    return "default", tags

def _include_dep(dep, markers, environment):
    if not markers:
        return True
    markers = json.decode(markers)
    if dep.label.name not in markers:
        return True

    marker = markers[dep.label.name]
    return evaluate(parse(marker, environment))

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

    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    runtime_info = toolchain.py3_runtime
    runtime_tag, tags = _derive_environment_markers(runtime_info.interpreter.path, ctx.attr.platforms)
    python_version = tags["python_version"]
    platform_tags = tags["platform_tags"]

    output = ctx.actions.declare_directory("{}/{}/{}".format(python_version, runtime_tag, ctx.label.name))

    arguments = [
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

    ctx.actions.run(
        outputs = [output],
        inputs = [],
        mnemonic = "InstallWheel",
        progress_message = "Installing package {} ({}) for Python {} {}".format(ctx.label.name, ctx.attr.constraint, python_version, runtime_tag),
        arguments = arguments,
        use_default_shell_env = True,
        executable = ctx.executable._poetry_deps,
        execution_requirements = {"requires-network": ""},
    )

    deps = [dep for dep in ctx.attr.deps if _include_dep(dep, ctx.attr.markers, tags)]
    transitive_imports = [dep[PyInfo].imports for dep in deps]
    transitive_depsets = [dep[PyInfo].transitive_sources for dep in deps]
    runfiles = [output] + [item for dep in transitive_depsets for item in dep.to_list()]
    files = depset([output], transitive = transitive_depsets)
    return [
        DefaultInfo(files = files, runfiles = ctx.runfiles(files = runfiles)),
        PyInfo(transitive_sources = files, imports = depset([output.short_path.replace("../", "")], transitive = transitive_imports)),
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
        "_poetry_deps": attr.label(default = ":poetry_deps", cfg = "exec", executable = True),
    },
    toolchains = [
        "@bazel_tools//tools/python:toolchain_type",
    ],
)
