# Test legacy WORKSPACE initialization with multiple Python versions defined in rules_python

Explicitly set `--enable_bzlmod=false` to disable bzlmod.

Add rules_ophiuchus to `WORKSPACE` file as
```
load("@rules_ophiuchus//python:poetry_parse.bzl", "poetry_parse")
load("@rules_ophiuchus//python:repositories.bzl", install_poetry_dependencies = "install_dependencies")

install_poetry_dependencies()
poetry_parse(
    name = "poetry",
    lock = "//:poetry.lock",
)
```
