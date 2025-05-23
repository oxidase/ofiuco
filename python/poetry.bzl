load("@ofiuco_defs//:defs.bzl", _python_host_runtime = "python_host_runtime")
load("@rules_python//python:defs.bzl", "PyRuntimeInfo")
load("//python/private:poetry_deps.bzl", _get_imports = "get_imports")

def _poetry_update_impl(ctx):
    interpreter = ctx.attr._python_host
    runtime_info = interpreter[PyRuntimeInfo]

    script = """#!{python}

import runpy
import sys
from pathlib import Path

_LOCK_FILE_NAME = "poetry.lock"

if __name__ == "__main__":
    sys.path = {deps} + sys.path
    dir = Path('{toml}').parent
    lock = Path('{lock}')
    poetry_lock = dir / _LOCK_FILE_NAME
    poetry_lock_is_same = lock.name == _LOCK_FILE_NAME and lock.resolve() == poetry_lock.resolve()
    if not poetry_lock_is_same:
        if poetry_lock.exists():
            poetry_lock.unlink()
        poetry_lock.symlink_to(lock.resolve())
    sys.argv = [sys.argv[0], "lock", f"--directory={{dir}}"{update}, *sys.argv[1:]]
    runpy.run_module("poetry", run_name="__main__", alter_sys=True)
""".format(
        python = runtime_info.interpreter.short_path,
        deps = repr(["../{}".format(path) for path in _get_imports(ctx.attr._poetry_deps).to_list()]),
        toml = ctx.attr.toml.files.to_list().pop().short_path,
        lock = ctx.attr.lock.files.to_list().pop().short_path,
        update = "" if ctx.attr.update else ', "--no-update"',
    )

    output = ctx.actions.declare_file(ctx.label.name + ".update")
    ctx.actions.write(output, script, is_executable = True)
    runfiles = ctx.runfiles(transitive_files = depset(transitive = [ctx.attr.toml.files, ctx.attr.lock.files, runtime_info.files]))
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
        "update": attr.bool(default = True),
        "_poetry_deps": attr.label(default = "@ofiuco_poetry_deps//:pkg"),
        "_python_host": attr.label(default = _python_host_runtime),
    },
)
