load("@python//3.12:defs.bzl", py_test_3_12 = "py_test")
load("@python//3.11:defs.bzl", py_test_3_11 = "py_test")
load("@python//3.10:defs.bzl", py_test_3_10 = "py_test")
load("@python//3.9:defs.bzl", py_test_3_9 = "py_test")
load("@python//3.8:defs.bzl", py_test_3_8 = "py_test")

[
    py_test(
        name = "test{}_{}".format(
            order,
            str(py_test).split("@")[-1].split("/")[0],
        ),
        size = "large",
        srcs = ["test.py"],
        data = ["poetry.lock"],
        env = {"PYTEST_ORDER": order},
        main = "test.py",
        deps = deps,
    )
    for py_test in [
        py_test_3_12,
        py_test_3_11,
        py_test_3_10,
        py_test_3_9,
        py_test_3_8,
    ]
    for order, deps in [
        [
            "12",
            [
                "@poetry_repo1//:pytest",
                "@poetry_repo2//:pytest",
            ],
        ],
        [
            "21",
            [
                "@poetry_repo2//:pytest",
                "@poetry_repo1//:pytest",
            ],
        ],
    ]
]
