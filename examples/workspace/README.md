# Test legacy WORKSPACE initialization

Explicitly set `--enable_bzlmod=false` to disable bzlmod.

Add rules_ophiuchus to `WORKSPACE` file as
```
load("@rules_ophiuchus//python:repositories.bzl", install_poetry_dependencies = "install_dependencies")

install_poetry_dependencies("black_mamba", "3.11")

load("@rules_ophiuchus//python:poetry_parse.bzl", "poetry_parse")

poetry_parse(
    name = "poetry",
    lock = "//:poetry.lock",
)
```
where `black_mamba` and 3.11 are toolchain name and version for lock files processing.
