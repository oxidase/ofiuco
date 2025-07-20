load("//lib/private:globstar.bzl", globstar = "globstar")
load("//lib/private:py_zip.bzl", py_zip = "py_zip")
load("//lib/private:prefix_lookup.bzl", prefix_lookup = "prefix_lookup")
load("//lib/private:runfiles.bzl", runfiles = "runfiles")

lib = struct(
    globstar = globstar,
    py_zip = py_zip,
    prefix_lookup = prefix_lookup,
    runfiles = runfiles,
)
