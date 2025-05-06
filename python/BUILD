load("@rules_python//python:defs.bzl", "py_binary", "py_library")

py_binary(
    name = "poetry_deps",
    srcs = ["poetry_deps.py"],
    visibility = ["__subpackages__"],
    deps = [
        ":utils",
        "@ofiuco_pip//:pkg",
    ],
)

py_library(
    name = "utils",
    srcs = ["utils.py"],
)

py_binary(
    name = "py_venv",
    srcs = ["py_venv.py"],
    visibility = ["__subpackages__"],
    deps = [":utils"],
)
