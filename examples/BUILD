sh_test(
    name = "simple_integration_test",
    size = "medium",
    srcs = ["integration_test.sh"],
    args = ["simple"],
    data = glob(["simple/**/*"]) + ["//:MODULE.bazel"],
)

sh_test(
    name = "torch_integration_test",
    size = "large",
    srcs = ["integration_test.sh"],
    args = ["torch"],
    data = glob(["torch/**/*"]) + ["//:MODULE.bazel"],
)

sh_test(
    name = "transitions_integration_test",
    size = "medium",
    srcs = ["integration_test.sh"],
    args = ["transitions"],
    data = glob(["transitions/**/*"]) + ["//:MODULE.bazel"],
)
