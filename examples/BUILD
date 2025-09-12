load("@rules_shell//shell:sh_test.bzl", "sh_test")

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
    "numpy",
    "simple",
    "torch",
    "transitions",
    "uv",
]]
