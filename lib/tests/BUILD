load(":globstar_test.bzl", "globstar_test_suite")
load(":py_zip_test.bzl", "py_zip_test_suite")
load(":runfiles_test.bzl", "runfiles_test_suite")

globstar_test_suite()

py_zip_test_suite()

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

platform(
    name = "lambda",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:arm64",
    ],
)
