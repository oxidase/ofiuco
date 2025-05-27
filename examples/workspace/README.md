# Test legacy WORKSPACE initialization

Explicitly set `--enable_bzlmod=false` to disable bzlmod.

Add `ofiuco` to `WORKSPACE` file as
```
load("@ofiuco//python:repositories.bzl", install_poetry_dependencies = "install_dependencies")

install_poetry_dependencies("black_mamba", "3.11")

load("@ofiuco//python:lock_parser.bzl", "parse_lock")

parse_lock(
    name = "poetry",
    lock = "//:poetry.lock",
)
```
where `black_mamba` and 3.11 are toolchain name and version for lock files processing.
