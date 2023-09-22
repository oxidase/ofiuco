load("@rules_poetry_deps//:defs.bzl", _python = "python")

def _poetry_update_impl(ctx):
    script = """#!{python}

import runpy
import sys
from pathlib import Path

_LOCK_FILE_NAME = "poetry.lock"

if __name__ == "__main__":
    import os
    sys.path = {deps} + sys.path
    dir = Path('{toml}').parent
    lock = Path('{lock}')
    poetry_lock = dir / _LOCK_FILE_NAME
    poetry_lock_is_same = lock.name == _LOCK_FILE_NAME and lock.resolve() == poetry_lock.resolve()
    if not poetry_lock_is_same:
        if poetry_lock.exists():
            poetry_lock.unlink()
        poetry_lock.symlink_to(lock.resolve())
    sys.argv = [sys.argv[0], "lock", "--no-update", f"--directory={{dir}}"]
    runpy.run_module("poetry", run_name="__main__", alter_sys=True)
""".format(
        python = _python,
        deps = repr(["../{}".format(path) for path in ctx.attr._poetry_deps[PyInfo].imports.to_list()]),
        toml = ctx.attr.toml.files.to_list().pop().short_path,
        lock = ctx.attr.lock.files.to_list().pop().short_path,
    )

    output = ctx.actions.declare_file(ctx.label.name + ".update")
    ctx.actions.write(output, script, is_executable = True)
    runfiles = ctx.runfiles(ctx.attr.toml.files.to_list() + ctx.attr.lock.files.to_list())
    runfiles = runfiles.merge(ctx.attr._poetry_deps.default_runfiles)

    return [
        DefaultInfo(executable = output, runfiles = runfiles),
    ]

poetry_update = rule(
    implementation = _poetry_update_impl,
    executable = True,
    attrs = {
        "toml": attr.label(allow_single_file = [".toml"]),
        "lock": attr.label(allow_single_file = [".lock"]),
        "_poetry_deps": attr.label(default = "@rules_poetry_deps//:pkg"),
    },
)
