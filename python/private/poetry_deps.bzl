load("@ofiuco_defs//:defs.bzl", _python_toolchain_prefix = "python_toolchain_prefix", _python_version = "python_version")
load("@rules_python//python:defs.bzl", "PyInfo")
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
    "aarch64-unknown-linux-gnu": """{"os_name": "posix", "platform_machine": "arm64", "platform_system": "Linux", "platform_tags": ["manylinux_2_17_arm64", "manylinux_2_17_aarch64"], "sys_platform": "linux"}""",
    "x86_64-apple-darwin": """{"os_name": "posix", "platform_machine": "x86_64", "platform_system": "Darwin", "platform_tags": ["macosx_10_15_x86_64"], "sys_platform": "darwin"}""",
    "x86_64-pc-windows-msvc": """{"os_name": "nt", "platform_machine": "x86_64", "platform_system": "Windows", "platform_tags": ["win_amd64"], "sys_platform": "win32"}""",
    "x86_64-unknown-linux-gnu": """{"os_name": "posix", "platform_machine": "x86_64", "platform_system": "Linux", "platform_tags": ["linux_x86_64", "manylinux2014_x86_64", "manylinux_2_12_x86_64", "manylinux_2_17_x86_64", "manylinux_2_27_x86_64", "manylinux_2_28_x86_64"], "sys_platform": "linux"}""",
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
    return target[PyInfo].imports if PyInfo in target else  depset()

def get_transitive_sources(target):
    return target[PyInfo].transitive_sources if PyInfo in target else depset()
