load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("//python:markers.bzl", "evaluate", "parse")

# Environment Markers https://peps.python.org/pep-0508/#environment-markers
_PLATFORM_MAPPING = {
    "aarch64-apple-darwin": {"platform_system": "Darwin", "platform_tag": "macosx_11_0_arm64", "sys_platform": "darwin", "os_name": "posix"},
    "aarch64-unknown-linux-gnu": {"platform_system": "Linux", "platform_tag": "manylinux_2_17_arm64", "sys_platform": "linux", "os_name": "posix"},
    "x86_64-apple-darwin": {"platform_system": "Darwin", "platform_tag": "macosx_10_15_x86_64", "sys_platform": "darwin", "os_name": "posix"},
    "x86_64-pc-windows-msvc": {"platform_system": "Windows", "platform_tag": "win_amd64", "sys_platform": "win32", "os_name": "nt"},
    "x86_64-unknown-linux-gnu": {"platform_system": "Linux", "platform_tag": "manylinux_2_17_x86_64", "sys_platform": "linux", "os_name": "posix"},
}

def _derive_tags(interpreter, constraints):
    tags = {
        "extra": "*",
        "implementation_name": "cpython",
        "platform_python_implementation": "CPython",
    }
    parts = interpreter.split("_")
    for index in range(len(parts) - 1):
        if parts[index].endswith("python3") and parts[index + 1].isdigit():
            tags["python_version"] = "3.{}".format(parts[index + 1])
            break

    for fr, to in _PLATFORM_MAPPING.items():
        if fr in interpreter:
            tags.update(**to)
            break

    return tags

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
        version: string The package version.
        description: string The package description.
        deps: label_list The package dependencies list.
        files: string_dict The dictionary of resolved file names with corresponding checksum.
        markers: string The JSON string with markers accordingly to PEP 508 – Dependency specification for Python Software Packages.
        constraints: label_list The list of platform constraints (currently unused).

    Private attributes:
        _poetry_deps:

    Returns:
        The providers list or a tuple with a Poetry package.

    Required toolchains:
         @bazel_tools//tools/python:toolchain_type
    """

    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    runtime_info = toolchain.py3_runtime
    target_platforms_constraints = {}
    for constraint in ctx.attr.constraints:
        constraint_info = constraint[platform_common.ConstraintValueInfo]
        if ctx.target_platform_has_constraint(constraint_info) and constraint.label.workspace_name == "platforms":
            target_platforms_constraints[constraint.label.package] = constraint.label.name

    tags = _derive_tags(runtime_info.interpreter.path, target_platforms_constraints)
    python_version = tags["python_version"]
    platform_tag = tags["platform_tag"]

    output = ctx.actions.declare_directory("{}/{}/{}".format(python_version, platform_tag, ctx.label.name))
    arguments = [
        ctx.attr.name,
        ctx.attr.version,
        "--python-version",
        python_version,
        "--platform",
        platform_tag,
        "--output",
        output.path,
        "--files",
        json.encode(ctx.attr.files),
    ]

    if ctx.attr.source_url:
        arguments += [
            "--source-url",
            ctx.attr.source_url,
        ]

    ctx.actions.run(
        outputs = [output],
        mnemonic = "InstallWheel",
        progress_message = "Installing Python package {} for Python {} {}".format(ctx.label.name, python_version, platform_tag),
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
        "version": attr.string(mandatory = True, doc = "The package exact version string"),
        "description": attr.string(doc = "The package description"),
        "deps": attr.label_list(doc = "The package dependencies list"),
        "files": attr.string_dict(doc = "The package resolved files"),
        "markers": attr.string(doc = "The JSON string with a dictionary of dependency markers accordingly to PEP 508"),
        "source_url": attr.string(doc = "The source file URL"),
        "constraints": attr.label_list(
            default = [
                "@platforms//os:macos",
                "@platforms//os:linux",
                "@platforms//os:windows",
                "@platforms//cpu:x86_64",
                "@platforms//cpu:aarch64",
            ],
        ),
        "_poetry_deps": attr.label(default = ":poetry_deps", cfg = "exec", executable = True),
    },
    toolchains = [
        "@bazel_tools//tools/python:toolchain_type",
    ],
)
