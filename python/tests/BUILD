load(":markers_test.bzl", "markers_test_suite")
load(":poetry_deps_test.bzl", "poetry_deps_test_suite")
load(":poetry_parse_test.bzl", "poetry_parse_test_suite")
load("@rules_python//python:defs.bzl", "py_test")

markers_test_suite()

poetry_deps_test_suite()

poetry_parse_test_suite()

py_test(
    name = "poetry_deps_test",
    srcs = [
        "poetry_deps_test.py",
    ],
    data = [
        "resources/six-1.16.0-py2.py3-none-any.whl",
    ],
    deps = [
        "//python:poetry_deps",
    ],
)

py_test(
    name = "py_venv_test",
    srcs = [
        "py_venv_test.py",
    ],
    data = [
        "resources/six-1.16.0-py2.py3-none-any.whl",
    ],
    deps = [
        "//python:py_venv",
    ],
)
