load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_PACKAGES_ENDPOINT = "https://files.pythonhosted.org/packages/"

# curl -s --header 'Accept: application/vnd.pypi.simple.v1+json' https://pypi.org/simple/pip/ | jq -r '.files[] | "\"\(.url)\", \"\(.hashes.sha256)\""'
_POETRY_INTERNAL_DEPS = [
    (
        "pip",
        _PACKAGES_ENDPOINT + "50/c2/e06851e8cc28dcad7c155f4753da8833ac06a5c704c109313b8d5a62968a/pip-23.2.1-py3-none-any.whl",
        "7ccf472345f20d35bdc9d1841ff5f313260c2c33fe417f48c30ac46cccabf5be",
        [":patches/scripts_executable.patch"],
    ),
]

def _poetry_deps_repo_impl(ctx):
    poetry_version = "1.4.1"

    # Intentionally use a host default interpreter as the repository only used in host tooling targets
    # This may lead to inconsistency if the repository will be used with a different toolchain
    python = ctx.which("python.exe" if "win" in ctx.os.name else "python3")
    if python:
        ctx.execute(
            [python, "-m", "pip", "install", "poetry=={}".format(poetry_version), "--target", ctx.attr.output],
            environment = {
                "PYTHONPATH": ":".join([str(ctx.path(dep).dirname) for dep in ctx.attr.deps]),
            },
        )

        build_file_content = """py_library(
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
)""".format(output = ctx.attr.output)

    else:
        build_file_content = "# Poetry deps require an installed host Python 3 interpreter"

    ctx.file("BUILD", build_file_content)
    ctx.file("defs.bzl", 'python = "{}"'.format(python))

poetry_deps_repo = repository_rule(
    implementation = _poetry_deps_repo_impl,
    attrs = {
        "deps": attr.label_list(),
        "output": attr.string(),
    },
)

def install_dependencies(auth_patterns = {}, netrc = ""):
    prefix = "rules_poetry_"

    for (name, url, sha256, patches) in _POETRY_INTERNAL_DEPS:
        maybe(
            http_archive,
            prefix + name,
            url = url,
            sha256 = sha256,
            type = "zip",
            patches = patches,
            auth_patterns = auth_patterns,
            netrc = netrc,
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

    poetry_deps_repo(
        name = prefix + "deps",
        output = "site-packages",
        deps = [
            "@{}pip//:BUILD.bazel".format(prefix),
        ],
    )
