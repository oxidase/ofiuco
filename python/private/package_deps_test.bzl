"""Unit tests for package deps rule"""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//python/private:package_deps.bzl", "DEFAULT_PLATFORMS", "derive_environment_markers", "merge_defines")

def _derive_environment_markers_test_impl(ctx):
    env = unittest.begin(ctx)

    interpreter_path = "rules_python~~python~python_3_11_aarch64-apple-darwin/bin/python3"
    runtime, tags = derive_environment_markers(interpreter_path, DEFAULT_PLATFORMS, "{}")

    asserts.true(env, runtime == "aarch64-apple-darwin")
    asserts.true(env, "platform_tags" in tags)
    asserts.true(env, "python_version" in tags)
    asserts.true(env, "python_full_version" in tags)
    asserts.true(env, tags["python_version"] == "3.11")
    asserts.true(env, tags["python_full_version"][:5] == "3.11.")

    interpreter_path = "some/python/interpreter"
    runtime, tags = derive_environment_markers(interpreter_path, DEFAULT_PLATFORMS, "{}")
    asserts.true(env, runtime == "host")
    asserts.true(env, tags == {})

    return unittest.end(env)

def _derive_environment_markers_host_test_impl(ctx):
    env = unittest.begin(ctx)

    interpreter_path = "/bin/viper3"
    host_tags = {
        "python_version": "bla",
        "python_full_version": "blabla",
    }
    runtime, tags = derive_environment_markers(interpreter_path, {}, json.encode(host_tags))

    asserts.true(env, "python_version" in tags)
    asserts.true(env, "python_full_version" in tags)
    asserts.true(env, tags["python_version"] == host_tags["python_version"])
    asserts.true(env, tags["python_full_version"] == host_tags["python_full_version"])

    return unittest.end(env)

derive_environment_markers_test = unittest.make(_derive_environment_markers_test_impl)
derive_environment_markers_host_test = unittest.make(_derive_environment_markers_host_test_impl)


def _merge_defines_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.true(env, merge_defines([]) == [])

    defines = merge_defines([
        "X",
        "A=B",
        "PYTHON_PROGRAM_NAME='\"../rules_python++python+python_3_13_aarch64-apple-darwin/bin/python3\"'",
        "PYTHON_PATH='\"../ofiuco++parse+diskcache-5.6.3-py3-none-any\"'",
        "PYTHON_PROGRAM_NAME='\"../rules_python++python+python_3_13_aarch64-apple-darwin/bin/python3\"'",
        "PYTHON_PATH='\"../ofiuco++parse+MarkupSafe-3.0.2-cp313-cp313-macosx_11_0_arm64:../ofiuco++parse+jinja2-3.1.6-py3-none-any\"'",
        "PYTHON_PROGRAM_NAME='\"../rules_python++python+python_3_13_aarch64-apple-darwin/bin/python3\"'",
        "PYTHON_PATH='\"../ofiuco++parse+numpy-2.3.1-cp313-cp313-macosx_14_0_arm64\"'",
        "PYTHON_PROGRAM_NAME='\"../rules_python++python+python_3_13_aarch64-apple-darwin/bin/python3\"'",
        "PYTHON_PATH='\"../ofiuco++parse+typing_extensions-4.14.1-py3-none-any\"'",
        "PYTHON_PATH='\"x\"'",
        "PYTHON_PATH='\"../ofiuco++parse+numpy-2.3.1-cp313-cp313-macosx_14_0_arm64\"'",
    ])

    expected = [
        "A=B",
        "PYTHON_PATH='\"{}\"'".format(":".join([
            "../ofiuco++parse+diskcache-5.6.3-py3-none-any",
            "../ofiuco++parse+MarkupSafe-3.0.2-cp313-cp313-macosx_11_0_arm64",
            "../ofiuco++parse+jinja2-3.1.6-py3-none-any",
            "../ofiuco++parse+numpy-2.3.1-cp313-cp313-macosx_14_0_arm64",
            "../ofiuco++parse+typing_extensions-4.14.1-py3-none-any",
            "x",
        ])),
        "PYTHON_PROGRAM_NAME='\"../rules_python++python+python_3_13_aarch64-apple-darwin/bin/python3\"'",
        "X"]

    asserts.true(env, sorted(defines) == expected)

    return unittest.end(env)

merge_defines_test = unittest.make(_merge_defines_test_impl)


def package_deps_test_suite():
    unittest.suite(
        "package_deps_bzl_test",
        partial.make(derive_environment_markers_test),
        partial.make(derive_environment_markers_host_test),
        partial.make(merge_defines_test),
    )
