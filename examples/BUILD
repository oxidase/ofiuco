[sh_test(
    name = "{}_integration_test".format(name),
    size = "large",
    srcs = ["integration_test.sh"],
    args = [name],
    data = glob(["{}/**/*".format(name)]) + ["//:WORKSPACE"] + ([] if name.startswith("workspace") else ["//:MODULE.bazel"]),
) for name in [
    "aspect_rules_py",
    "cc_toolchain",
    "markers",
    "simple",
    "torch",
    "transitions",
    "workspace",
    "workspace_multi",
]]
