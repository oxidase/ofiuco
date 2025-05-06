load(":globstar_test.bzl", "globstar_test_suite")
load(":py_zip_test.bzl", "py_zip_test_suite")
load(":runfiles_test.bzl", "runfiles_test_suite")
load("@rules_python//python:defs.bzl", "py_binary")

globstar_test_suite()

py_zip_test_suite()

runfiles_test_suite()

filegroup(
    name = "test_filegroup",
    srcs = [
        "@ofiuco_pip//:pkg",
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

py_binary(
    name = "test_binary",
    srcs = ["test_binary.py"],
)
