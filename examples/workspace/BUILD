load("@rules_python//python:defs.bzl", "py_test")

py_test(
    name = "test",
    size = "large",
    srcs = ["test.py"],
    data = ["poetry.lock"],
    deps = [
        "@poetry//:pytest",
    ],
)
