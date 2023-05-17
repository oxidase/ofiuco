filegroup(
    name = "distribution",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"],
)

py_binary(
    name = "zipper",
    srcs = ["zipper.py"],
    visibility = ["//visibility:public"],
)
