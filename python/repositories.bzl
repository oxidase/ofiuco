load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_PACKAGES_ENDPOINT = "https://files.pythonhosted.org/packages/"

# curl -s --header 'Accept: application/vnd.pypi.simple.v1+json' https://pypi.org/simple/pip/ | jq -r '.files[] | "\"\(.url)\", \"\(.hashes.sha256)\""'
_INTERNAL_DEPS = [
    (
        "pip",
        _PACKAGES_ENDPOINT + "f4/ab/e3c039b5ddba9335bd8f82d599eb310de1d2a2db0411b8d804d507405c74/pip-24.1.1-py3-none-any.whl",
        "efca15145a95e95c00608afeab66311d40bfb73bb2266a855befd705e6bb15a0",
        ["@rules_ophiuchus//python:patches/scripts_executable.patch"],
    ),
]

def _poetry_deps_repo_impl(ctx):
    poetry_version = "1.8.3"

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
        build_file_content = "# Poetry deps require an installed host Python 3 interpreter"  # TODO: switch to a host interpreter from rules_python

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
    prefix = "rules_ophiuchus_"

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
        name = prefix + "poetry_deps",
        output = "site-packages",
        deps = [
            "@{}pip//:BUILD.bazel".format(prefix),
        ],
    )
