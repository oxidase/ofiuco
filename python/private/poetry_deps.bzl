load("@rules_python//python:versions.bzl", _MINOR_MAPPING = "MINOR_MAPPING")
load("//python:markers.bzl", "evaluate", "parse")
load("@rules_python//python:defs.bzl", StarPyInfo = "PyInfo")

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

def derive_environment_markers(interpreter, interpreter_markers):
    python_version = _get_python_version(interpreter)
    tags = {
        "extra": "*",
        "implementation_name": "cpython",
        "platform_python_implementation": "CPython",
        "platform_tags": [],
        "python_version": python_version,
        "python_full_version": _MINOR_MAPPING[python_version],
        "interpreter": interpreter,
    }

    for fr, to in interpreter_markers.items():
        if fr in interpreter:
            tags.update(**json.decode(to))
            return fr, tags

    return "default", tags

def include_dep(dep, markers, environment):
    if not markers:
        return True
    markers = json.decode(markers)
    if dep.label.name not in markers:
        return True

    marker = markers[dep.label.name]
    return evaluate(parse(marker, environment))

def get_imports(target):
    for info in [StarPyInfo, PyInfo]:
        if info in target:
            return target[info].imports
    return depset()

def get_transitive_sources(target):
    for info in [StarPyInfo, PyInfo]:
        if info in target:
            return target[info].transitive_sources
    return depset()
