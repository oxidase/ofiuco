load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("//python:markers.bzl", "evaluate", "parse")

# Environment Markers https://peps.python.org/pep-0508/#environment-markers
# Platform tags https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#platform-tag
_DEFAULT_PLATFORMS = {
    "aarch64-apple-darwin": """{"os_name": "posix", "platform_system": "Darwin", "platform_tags": ["macosx_11_0_arm64", "macosx_12_0_arm64"], "sys_platform": "darwin"}""",
    "aarch64-unknown-linux-gnu": """{"os_name": "posix", "platform_system": "Linux", "platform_tags": ["manylinux_2_17_arm64"], "sys_platform": "linux"}""",
    "x86_64-apple-darwin": """{"os_name": "posix", "platform_system": "Darwin", "platform_tags": ["macosx_10_15_x86_64"], "sys_platform": "darwin"}""",
    "x86_64-pc-windows-msvc": """{"os_name": "nt", "platform_system": "Windows", "platform_tags": ["win_amd64"], "sys_platform": "win32"}""",
    "x86_64-unknown-linux-gnu": """{"os_name": "posix", "platform_system": "Linux", "platform_tags": ["manylinux_2_12_x86_64", "manylinux_2_17_x86_64"], "sys_platform": "linux"}""",
}

def _get_python_version(interpreter):
    parts = interpreter.split("_")
    for index in range(len(parts) - 1):
        if parts[index].endswith("python3") and parts[index + 1].isdigit():
            return "3.{}".format(parts[index + 1])

    return "3"

def _derive_environment_markers(interpreter, interpreter_markers):
    tags = {
        "extra": "*",
        "implementation_name": "cpython",
        "platform_python_implementation": "CPython",
        "platform_tags": [],
        "python_version": _get_python_version(interpreter),
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

def _package_wheel_impl(ctx):
    """
    Rule to download a Python package.

    Arguments:
        ctx: The rule context.

    Attributes:
        version: string The package version.
        description: string The package description.
        deps: label_list The package dependencies list.
        files: string_dict The dictionary of resolved file names with corresponding checksum.
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
        "download",
        ctx.attr.constraint,
        "--python-version",
        python_version,
        "--output",
        output.path,
        "--files",
        json.encode(ctx.attr.files),
    ]

    for platform in platform_tags:
        arguments += ["--platform", platform]

    ctx.actions.run(
        outputs = [output],
        mnemonic = "DownloadWheel",
        progress_message = "Downloading package {} for Python {} {}".format(ctx.attr.constraint, python_version, runtime_tag),
        arguments = arguments,
        use_default_shell_env = True,
        executable = ctx.executable._poetry_deps,
    )

    return [
        DefaultInfo(files = depset([output])),
    ]

package_wheel = rule(
    implementation = _package_wheel_impl,
    attrs = {
        "constraint": attr.string(mandatory = True, doc = "The package version constraint string"),
        "description": attr.string(doc = "The package description"),
        "files": attr.string_dict(doc = "The package resolved files"),
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
    wheel_file = ctx.attr.wheel.files.to_list().pop()
    arguments = [
        "install",
        "url" if ctx.attr.url else "wheel",
        ctx.attr.url if ctx.attr.url else wheel_file.path,
        output.path,
        "--python-version",
        python_version,
    ]

    for platform in platform_tags:
        arguments += ["--platform", platform]

    ctx.actions.run(
        outputs = [output],
        inputs = [] if ctx.attr.url else [wheel_file],
        mnemonic = "InstallWheel",
        progress_message = "Installing package {} for Python {} {}".format(ctx.label.name, python_version, runtime_tag),
        arguments = arguments,
        use_default_shell_env = True,
        executable = ctx.executable._poetry_deps,
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
        "deps": attr.label_list(doc = "The package dependencies list"),
        "wheel": attr.label(doc = "The package_wheel target"),
        "url": attr.string(doc = "The source file URL"),
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
