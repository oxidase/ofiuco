"""unit tests for py_zip rule"""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//lib/private:py_zip.bzl", "py_zip")

EXCLUDE = ["**/*.dist-info/*", "**__*__???", "**_vendor**", "**.typed", "**poetry_pip/*"]

def _py_zip_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)

    files = {file.extension: file for file in target_under_test[DefaultInfo].files.to_list()}
    asserts.true(env, "zip" in files)

    return analysistest.end(env)

py_zip_test = analysistest.make(_py_zip_test_impl)

def _test_py_zip():
    py_zip(
        name = "test_py_zip_contents_subject.zip",
        target = "@ofiuco_pip//:pkg",
        exclude = EXCLUDE,
    )

    py_zip(
        name = "test_py_zip_transition_subject.zip",
        target = "@ofiuco_pip//:pkg",
        platform = ":lambda",
        exclude = EXCLUDE,
    )

    py_zip(
        name = "test_py_zip_with_main_subject.zip",
        target = ":py_zip_test_binary",
    )

    py_zip(
        name = "test_py_zip_without_main_subject.zip",
        target = ":py_zip_test_binary",
        exclude = ["__main__.py"],
    )

    py_zip(
        name = "test_py_zip_shebang_subject.pyz",
        target = ":py_zip_test_binary",
        shebang = "#!/usr/bin/env python3",
    )

    native.filegroup(
        name = "test_py_zip_shebang_subject",
        srcs = [":test_py_zip_contents_subject.zip"],
        output_group = "all",
    )

    py_zip_test(name = "py_zip_contents_test", target_under_test = ":test_py_zip_contents_subject.zip")
    py_zip_test(name = "py_zip_transition_test", target_under_test = ":test_py_zip_transition_subject.zip")
    py_zip_test(name = "py_zip_with_main_test", target_under_test = ":test_py_zip_with_main_subject.zip")
    py_zip_test(name = "py_zip_without_main_test", target_under_test = ":test_py_zip_without_main_subject.zip")

    sh_test(
        name = "py_zip_validation_test",
        srcs = ["py_zip_test_validator.sh"],
        args = ["$(locations :test_py_zip_shebang_subject)"],
        data = [":test_py_zip_shebang_subject"],
    )

    sh_test(
        name = "py_zip_has_main_test",
        srcs = ["py_zip_test_grep.sh"],
        args = ["$(locations :test_py_zip_with_main_subject.zip) -qce ' __main__.py'"],
        data = [":test_py_zip_with_main_subject.zip"],
    )

    sh_test(
        name = "py_zip_has_no_main_test",
        srcs = ["py_zip_test_grep.sh"],
        args = ["$(locations :test_py_zip_without_main_subject.zip) -vqce ' __main__.py'"],
        data = [":test_py_zip_without_main_subject.zip"],
    )

    sh_test(
        name = "py_zip_shebang_test",
        srcs = ["py_zip_test_shebang.sh"],
        args = ["$(locations :test_py_zip_shebang_subject.pyz)"],
        data = [":test_py_zip_shebang_subject.pyz"],
    )

    return [
        ":py_zip_contents_test",
        ":py_zip_transition_test",
        ":py_zip_validation_test",
        ":py_zip_with_main_test",
        ":py_zip_without_main_test",
        ":py_zip_has_main_test",
        ":py_zip_has_no_main_test",
        ":py_zip_shebang_test",
    ]

def py_zip_test_suite():
    py_zip_tests = _test_py_zip()

    native.test_suite(name = "py_zip", tests = py_zip_tests)
