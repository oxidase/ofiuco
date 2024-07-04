# Test legacy WORKSPACE initialization with multiple Python versions defined in rules_python

Explicitly set `--enable_bzlmod=false` to disable bzlmod.

Add `ofiuco` to `WORKSPACE` file as
```
load("@ofiuco//python:repositories.bzl", install_poetry_dependencies = "install_dependencies")

install_poetry_dependencies("copperhead_3_11", "3.11")

load("@ofiuco//python:poetry_parse.bzl", "poetry_parse")

poetry_parse(
    name = "poetry_repo1",
    lock = "//:poetry.lock",
)

poetry_parse(
    name = "poetry_repo2",
    lock = "//:poetry.lock",
)
```

where `copperhead_3_11` and 3.11 are toolchain name and version for lock files processing.
