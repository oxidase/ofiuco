
def _poetry_venv_impl(rctx):

    result = rctx.execute([
        "awk",
        "-f", rctx.attr._venv,
        rctx.attr.lock,
    ])
    if result.return_code != 0:
        fail("awk failed (status {}): {}".format(result.return_code, result.stderr))

    rules_repository = str(rctx.path(rctx.attr._venv)).split("/")[-3]
    rules_repository = ("@@" if "~" in rules_repository else "@") + rules_repository
    prefix = '''load("{name}//python:poetry_deps.bzl", "package")\n'''.format(name=rules_repository)
    rctx.file("BUILD",  prefix + result.stdout)
    rctx.file("WORKSPACE")


poetry_venv = repository_rule(
    attrs = {
        "lock": attr.label(
            allow_single_file = True,
            doc = "Poetry lock file",
        ),
        "_venv": attr.label(
            allow_single_file = True,
            default = ":poetry_venv.awk",
        ),
    },
    doc = """Process Poetry lock file.""",
    implementation = _poetry_venv_impl,
)
