sh_test(
    name = "simple_integration_test",
    size = "medium",
    srcs = ["integration_test.sh"],
    args = ["simple"],
    data = glob(["simple/**/*"]) + [
        "//:distribution",
    ],
)
