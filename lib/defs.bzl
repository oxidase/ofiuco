"""Public library functions."""

load("//lib/private:globstar.bzl", "globstar")
load("//lib/private:paths.bzl", "pathsep")
load("//lib/private:prefix_lookup.bzl", "prefix_lookup")
load("//lib/private:py_zip.bzl", "py_zip")
load("//lib/private:runfiles.bzl", "runfiles")

lib = struct(
    globstar = globstar,
    py_zip = py_zip,
    prefix_lookup = prefix_lookup,
    runfiles = runfiles,
    pathsep = pathsep,
)
