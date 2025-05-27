"""unit tests for py_zip rule"""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//lib:py_zip.bzl", "py_zip")

EXCLUDE = ["**/*.dist-info/*", "**__*__???", "**_vendor**", "**.typed", "**poetry_pip/*"]

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
        target = "@ofiuco_pip//:pkg",
        exclude = EXCLUDE,
    )

    py_zip(
        name = "test_py_zip_transition_subject",
        target = "@ofiuco_pip//:pkg",
        platform = ":lambda",
        exclude = EXCLUDE,
    )

    py_zip(
        name = "test_py_zip_with_main_subject",
        target = ":py_zip_test_binary",
    )

    py_zip(
        name = "test_py_zip_without_main_subject",
        target = ":py_zip_test_binary",
        exclude = ["__main__.py"],
    )

    py_zip_test(name = "py_zip_contents_test", target_under_test = ":test_py_zip_contents_subject")
    py_zip_test(name = "py_zip_transition_test", target_under_test = ":test_py_zip_transition_subject")
    py_zip_test(name = "py_zip_with_main_test", target_under_test = ":test_py_zip_with_main_subject")
    py_zip_test(name = "py_zip_without_main_test", target_under_test = ":test_py_zip_without_main_subject")

    sh_test(
        name = "py_zip_validation_test",
        srcs = ["py_zip_test_validator.sh"],
        args = ["$(locations :test_py_zip_contents_subject)"],
        data = [":test_py_zip_contents_subject"],
    )

    sh_test(
        name = "py_zip_has_main_test",
        srcs = ["py_zip_test_grep.sh"],
        args = ["$(locations :test_py_zip_with_main_subject) -qce ' __main__.py'"],
        data = [":test_py_zip_with_main_subject"],
    )

    sh_test(
        name = "py_zip_has_no_main_test",
        srcs = ["py_zip_test_grep.sh"],
        args = ["$(locations :test_py_zip_without_main_subject) -vqce ' __main__.py'"],
        data = [":test_py_zip_without_main_subject"],
    )

    return [
        ":py_zip_contents_test",
        ":py_zip_transition_test",
        ":py_zip_validation_test",
        ":py_zip_with_main_test",
        ":py_zip_without_main_test",
        ":py_zip_has_main_test",
        ":py_zip_has_no_main_test",
    ]

def py_zip_test_suite():
    py_zip_tests = _test_py_zip()

    native.test_suite(name = "py_zip", tests = py_zip_tests)
