"""unit tests for globstar poetry_venv repository rule"""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//python/private:poetry_deps.bzl", "derive_environment_markers")

def _derive_environment_markers_test_impl(ctx):
    env = unittest.begin(ctx)

    interpreter_path = "rules_python~~python~python_3_11_aarch64-apple-darwin/bin/python3"
    runtime, tags = derive_environment_markers(interpreter_path, {})

    asserts.true(env, "python_version" in tags)
    asserts.true(env, "python_full_version" in tags)
    asserts.true(env, tags["python_version"] == "3.11")
    asserts.true(env, tags["python_full_version"][:5] == "3.11.")

    return unittest.end(env)

derive_environment_markers_test = unittest.make(_derive_environment_markers_test_impl)

def poetry_deps_test_suite():
    unittest.suite(
        "poetry_deps_bzl_test",
        partial.make(derive_environment_markers_test),
    )
