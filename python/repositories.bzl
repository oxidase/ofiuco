load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_PACKAGES_ENDPOINT = "https://files.pythonhosted.org/packages/"

# curl -s --header 'Accept: application/vnd.pypi.simple.v1+json' https://pypi.org/simple/pip/ | jq -r '.files[] | "\"\(.url)\", \"\(.hashes.sha256)\""'
_INTERNAL_DEPS = [
    (
        "pip",
        _PACKAGES_ENDPOINT + "29/a2/d40fb2460e883eca5199c62cfc2463fd261f760556ae6290f88488c362c0/pip-25.1.1-py3-none-any.whl",
        "2913a38a2abf4ea6b64ab507bd9e967f3b53dc1ede74b01b0931e1ce548751af",
        ["@ofiuco//python:patches/scripts_executable.patch"],
    ),
]

_POETRY_VERSION = "1.8.3"

# TODO: drop it
def _poetry_deps_repo_impl(rctx):
    interpreter = rctx.path(rctx.attr.python_host)

    rctx.execute(
        [interpreter, "-m", "pip", "install", "poetry=={}".format(_POETRY_VERSION), "--target", rctx.attr.output],
        environment = {
            "PYTHONPATH": ":".join([str(rctx.path(dep).dirname) for dep in rctx.attr.deps]),
        },
    )

    rctx.file("BUILD", """load("@rules_python//python:defs.bzl", "py_library")

exports_files(["defs.bzl"])

py_library(
    name = "pkg",
    srcs = glob(include=["{output}/**/*.py"]),
    data = glob(include=["{output}/**/*"], exclude=[
        "{output}/*/bin/**/*",
        "**/*.py",
        "**/*.pyc",
        "**/* *",
        "**/*.dist-info/RECORD",
    ]),
    visibility = ["//visibility:public"],
    imports = ["{output}"],
)""".format(output = rctx.attr.output))

# TODO: drop it
poetry_deps_repo = repository_rule(
    implementation = _poetry_deps_repo_impl,
    attrs = {
        "deps": attr.label_list(),
        "output": attr.string(),
        "python_host": attr.label(),
    },
)

def _internal_definitions_repo_impl(rctx):
    rctx.file("BUILD", "")
    rctx.file("defs.bzl", """
python_host = "{python_host}"
python_version = "{python_version}"
python_toolchain_prefix = "{python_toolchain_prefix}"
""".format(
        python_host = rctx.attr.python_host,
        python_version = rctx.attr.python_version,
        python_toolchain_prefix = rctx.attr.python_toolchain_prefix,
    ))

internal_definitions_repo = repository_rule(
    implementation = _internal_definitions_repo_impl,
    attrs = {
        "python_host": attr.label(),
        "python_version": attr.string(),
        "python_toolchain_prefix": attr.string(),
    },
)

def install_dependencies(toolchain_prefix, python_version, auth_patterns = {}, netrc = ""):
    prefix = "ofiuco_"

    internal_definitions_repo(
        name = prefix + "defs",
        # Ref: https://github.com/bazelbuild/rules_python/blob/084b877c/python/repositories.bzl#L653-L658
        python_host = "@{name}_host//:python".format(name = toolchain_prefix),
        python_version = python_version,
        python_toolchain_prefix = toolchain_prefix.split("_3_")[0],
    )

    for (name, url, sha256, patches) in _INTERNAL_DEPS:
        maybe(
            http_archive,
            prefix + name,
            url = url,
            sha256 = sha256,
            type = "zip",
            patches = patches,
            auth_patterns = auth_patterns,
            netrc = netrc,
            build_file_content = """load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "pkg",
    srcs = glob(include=["**/*.py"]),
    data = glob(include=["**/*"], exclude=[
        "bin/**/*",
        "**/__pycache__/**",
        "**/*.py",
        "**/*.pyc",
        "**/* *",
        "**/*.dist-info/RECORD",
    ]),
    visibility = ["//visibility:public"],
    imports = ["."],
)
""",
        )

    # TODO: Switch to internal poetry.lock file
    poetry_deps_repo(
        name = prefix + "poetry_deps",
        output = "site-packages",
        python_host = "@{name}_host//:python".format(name = toolchain_prefix),
        deps = [
            "@{}pip//:BUILD.bazel".format(prefix),
        ],
    )
