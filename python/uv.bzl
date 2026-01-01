"""Rules for uv lock files."""

load("@ofiuco_defs//:defs.bzl", _python_host_runtime = "python_host_runtime")
load("@rules_python//python:defs.bzl", "PyRuntimeInfo")

def _uv_lock_impl(ctx):
    interpreter = ctx.attr._python_host
    runtime_info = interpreter[PyRuntimeInfo]

    script = """#!{python}

import os
import subprocess
import sys
from itertools import dropwhile
from pathlib import Path


_LOCK_FILE_NAME = "uv.lock"


if __name__ == "__main__":
    lock_file = Path('{lock}')
    project_dir = Path('{toml}').resolve().parent
    project_lock = project_dir / _LOCK_FILE_NAME
    create_symlink = not project_lock.exists() and lock_file.stat().st_size > 0

    if create_symlink:
        project_lock.symlink_to(lock_file)

    argv = sys.argv[1:]
    right = list(dropwhile(lambda x: x != "--", argv))[1:]
    argv = right if right else ["lock", "--project", os.fspath(project_dir)] + argv

    result = subprocess.run([Path("{uv}").resolve()] + argv, cwd=project_dir, capture_output=False)

    if create_symlink and project_lock.exists():
        project_lock.unlink()

    sys.exit(result.returncode)
""".format(
        python = runtime_info.interpreter.short_path,
        uv = ctx.executable._uv.short_path,
        toml = ctx.attr.toml.files.to_list().pop().short_path,
        lock = ctx.attr.lock.files.to_list().pop().short_path,
        update = "" if ctx.attr.update else ', "--no-update"',
    )

    output = ctx.actions.declare_file(ctx.label.name + ".update")
    ctx.actions.write(output, script, is_executable = True)
    runfiles = ctx.runfiles(transitive_files = depset(transitive = [ctx.attr.toml.files, ctx.attr.lock.files, ctx.attr._uv.files, runtime_info.files]))

    return [
        DefaultInfo(executable = output, runfiles = runfiles),
    ]

uv_lock = rule(
    implementation = _uv_lock_impl,
    executable = True,
    attrs = {
        "toml": attr.label(allow_single_file = [".toml"]),
        "lock": attr.label(allow_single_file = [".lock"]),
        "update": attr.bool(default = True),
        "_python_host": attr.label(default = _python_host_runtime),
        "_uv": attr.label(default = "@multitool//tools/uv", executable = True, cfg = "exec"),
    },
)
