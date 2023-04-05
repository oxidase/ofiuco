"""unit tests for py_zip rule"""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//lib:py_zip.bzl", "py_zip")

def _py_zip_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)

    files = {file.extension: file for file in target_under_test[DefaultInfo].files.to_list()}
    asserts.true(env, "zip" in files)
    asserts.true(env, "json" in files)
    asserts.true(env, files["zip"].basename.split(".")[0] == files["json"].basename.split(".")[0])

    return analysistest.end(env)

py_zip_test = analysistest.make(_py_zip_test_impl)

def _test_py_zip():
    py_zip(
        name = "test_py_zip_contents_subject",
        target = "@rules_poetry_pip//:pkg",
        exclude = ["**/*.dist-info/*", "**__*__???", "**_vendor**", "**.typed", "**poetry_pip/*"],
    )

    py_zip_test(name = "py_zip_contents_test", target_under_test = ":test_py_zip_contents_subject")

    native.sh_test(
        name = "py_zip_validate",
        srcs = ["py_zip_validator.sh"],
        args = ["$(locations :test_py_zip_contents_subject)"],
        data = [":test_py_zip_contents_subject"],
    )

    return [":py_zip_contents_test", ":py_zip_validate"]

def py_zip_test_suite():
    py_zip_tests = _test_py_zip()

    native.test_suite(name = "py_zip", tests = py_zip_tests)
