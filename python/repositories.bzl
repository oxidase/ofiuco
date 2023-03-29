load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# curl -s --header 'Accept: application/vnd.pypi.simple.v1+json' https://pypi.org/simple/pip/ | jq -r '.files[] | "\"\(.url)\", \"\(.hashes.sha256)\""'
_POETRY_INTERNAL_DEPS = [
    (
        "pip",
        "https://files.pythonhosted.org/packages/07/51/2c0959c5adf988c44d9e1e0d940f5b074516ecc87e96b1af25f59de9ba38/pip-23.0.1-py3-none-any.whl",
        "236bcb61156d76c4b8a05821b988c7b8c35bf0da28a4b614e8d6ab5212c25c6f"
    ),
]

def install_dependencies():
    for (name, url, sha256) in _POETRY_INTERNAL_DEPS:
        maybe(
            http_archive,
            "rules_poetry_" + name,
            url = url,
            sha256 = sha256,
            type = "zip",
            build_file_content = """py_library(
    name = "pkg",
    srcs = glob(include=["**/*.py"]),
    data = glob(include=["**/*"], exclude=[
        "bin/**/*",
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
