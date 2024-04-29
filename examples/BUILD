[sh_test(
    name = "{}_integration_test".format(name),
    size = "medium",
    srcs = ["integration_test.sh"],
    args = [name],
    data = glob(["{}/**/*".format(name)]) + ["//:MODULE.bazel"],
) for name in [
    "markers",
    "simple",
    "torch",
    "transitions",
]]
