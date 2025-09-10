"""unit tests for runfiles rule"""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//lib/private:runfiles.bzl", "matches", "runfiles")

def _matches_test(ctx):
    env = unittest.begin(ctx)

    file_path = "src/test.py"
    asserts.equals(env, True, matches(file_path, ["**"]))
    asserts.equals(env, True, matches(file_path, ["**.py"]))
    asserts.equals(env, True, matches(file_path, ["src", "**.py"]))
    asserts.equals(env, False, matches(file_path, ["*"]))
    asserts.equals(env, False, matches(file_path, []))

    asserts.equals(env, True, matches("", ["*"]))
    asserts.equals(env, False, matches("/", ["*"]))
    asserts.equals(env, True, matches("/", ["*"], None))

    asserts.equals(env, True, matches("", ["**"]))
    asserts.equals(env, True, matches("/", ["**"]))

    asserts.equals(env, False, matches("", ["?**"]))
    asserts.equals(env, False, matches("/", ["?**"]))
    asserts.equals(env, True, matches("/", ["?**"], None))

    return unittest.end(env)

matches_test = unittest.make(_matches_test)

def _runfiles_provider_default_workspace_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)

    files = target_under_test[DefaultInfo].files.to_list()
    asserts.equals(env, 2, len(files))
    for file in files:
        asserts.true(env, file.path.endswith(".bzl"))

    return analysistest.end(env)

runfiles_provider_default_workspace_test = analysistest.make(_runfiles_provider_default_workspace_test_impl)

def _test_runfiles_provider_default_workspace():
    runfiles(
        name = "runfiles_default_workspace_contents_subject",
        data = [":test_filegroup"],
        workspace = [""],
        include = ["**"],
        exclude = ["**/tests*/??I*"],
    )

    runfiles_provider_default_workspace_test(
        name = "runfiles_default_workspace_contents_test",
        target_under_test = ":runfiles_default_workspace_contents_subject",
    )

def _runfiles_provider_external_workspace_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)

    files = target_under_test[DefaultInfo].files.to_list()
    asserts.true(env, files)
    for file in files:
        asserts.true(env, file.path.startswith("external/"))
        asserts.true(env, "/pip/_internal/" in file.path and file.path.endswith(".py") or file.path.endswith(".txt"))

    return analysistest.end(env)

runfiles_provider_external_workspace_test = analysistest.make(_runfiles_provider_external_workspace_test_impl)

def _test_runfiles_provider_external_workspace():
    runfiles(
        name = "runfiles_external_workspace_contents_subject",
        data = [":test_filegroup"],
        workspace = ["?**"],
        include = ["*/**"],
        exclude = ["**/*.dist-info/*", "**__*__???", "**_vendor**", "**.typed", "**ofiuco_pip/*"],
    )

    runfiles_provider_external_workspace_test(
        name = "runfiles_external_workspace_contents_test",
        target_under_test = ":runfiles_external_workspace_contents_subject",
    )

def runfiles_test_suite():
    _test_runfiles_provider_default_workspace()
    _test_runfiles_provider_external_workspace()

    unittest.suite(
        "matches",
        partial.make(matches_test, timeout = "short"),
    )

    native.test_suite(
        name = "runfiles",
        tests = [
            ":runfiles_default_workspace_contents_test",
            ":runfiles_external_workspace_contents_test",
        ],
    )
