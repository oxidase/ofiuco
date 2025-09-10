"""Unit tests for prefix_lookup."""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//lib/private:prefix_lookup.bzl", "prefix_lookup")

def _basic(ctx):
    env = unittest.begin(ctx)

    d = {"xxx": 1, "x": 2}
    asserts.equals(env, (None, None), prefix_lookup(d, ""))
    asserts.equals(env, ("x", 2), prefix_lookup(d, "x"))
    asserts.equals(env, ("x", 2), prefix_lookup(d, "xx"))
    asserts.equals(env, ("xxx", 1), prefix_lookup(d, "xxx"))
    asserts.equals(env, ("xxx", 1), prefix_lookup(d, "xxxx"))
    asserts.equals(env, ("xxx", 1), prefix_lookup(d, "xxxxx"))
    asserts.equals(env, ("xxx", 1), prefix_lookup(d, "xxxxy"))
    asserts.equals(env, ("xxx", 1), prefix_lookup(d, "xxxyy"))
    asserts.equals(env, ("x", 2), prefix_lookup(d, "xxyyy"))
    asserts.equals(env, ("x", 2), prefix_lookup(d, "xyyyy"))
    asserts.equals(env, (None, None), prefix_lookup(d, "yyyyy"))

    asserts.equals(env, (None, 3), prefix_lookup(d, "y", 3))
    asserts.equals(env, (None, 3), prefix_lookup(d, "", 3))
    asserts.equals(env, ("", 4), prefix_lookup({"": 4}, "", 3))

    return unittest.end(env)

basic_test = unittest.make(_basic)


def prefix_lookup_test_suite():
    unittest.suite(
        "prefix_lookup",
        partial.make(basic_test, timeout = "short"),
    )
