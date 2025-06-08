load("@ofiuco_defs//:defs.bzl", _python_host_runtime = "python_host_runtime")
load("@rules_python//python:defs.bzl", "PyRuntimeInfo")
load("//python/private:poetry_deps.bzl", _get_imports = "get_imports")

def _poetry_update_impl(ctx):
    interpreter = ctx.attr._python_host
    runtime_info = interpreter[PyRuntimeInfo]

    script = """#!{python}

import builtins
import runpy
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch
from multiprocessing import Process

_LOCK_FILE_NAME = "poetry.lock"

@contextmanager
def redirect_open(files_remap: dict[str, str | Path]):
    open_original = builtins.open

    def custom_open(file, mode="r", *args, **kwargs):
        return open_original(files_remap.get(os.fspath(file), file), mode, *args, **kwargs)

    with patch("builtins.open", new=custom_open):
        yield

def lock(project_dir, lock_file):
    sys.argv = [sys.argv[0], "lock", f"--project={{project_dir}}"{update}, *sys.argv[1:]]
    files_remap = {{os.fspath(project_dir / _LOCK_FILE_NAME): lock_file}}
    with redirect_open(files_remap):
        runpy.run_module("poetry", run_name="__main__", alter_sys=True)


if __name__ == "__main__":
    sys.path = {deps} + sys.path
    lock_file = Path('{lock}')
    project_dir = Path('{toml}').resolve().parent

    # TODO: make locker independent from user configuration
    # https://python-poetry.org/docs/configuration/#config-directory
    os.environ["POETRY_CONFIG_DIR"] = os.path.join(os.getcwd(), "pypoetry")

    lock_process = Process(target=lock, args=(project_dir, lock_file))
    lock_process.start()
    lock_process.join()
    sys.exit(lock_process.exitcode)
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
