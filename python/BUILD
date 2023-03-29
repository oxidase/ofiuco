filegroup(
    name = "distribution",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"],
)

py_binary(
    name = "poetry_deps",
    srcs = ["poetry_deps.py"],
    visibility = ["//visibility:public"],
    deps = [
        "@rules_poetry_pip//:pkg",
    ],
)
