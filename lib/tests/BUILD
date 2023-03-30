load(":globstar_test.bzl", "globstar_test_suite")
load(":runfiles_test.bzl", "runfiles_test_suite")

globstar_test_suite()

runfiles_test_suite()

filegroup(
    name = "test_filegroup",
    srcs = [
        "@rules_poetry_pip//:pkg",
    ],
    data = [
        "BUILD",
        "globstar_test.bzl",
        "runfiles_test.bzl",
    ],
)
