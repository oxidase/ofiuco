# Python Poetry Rules for Bazel

## Overview

The repository defines Bazel installation rules for [Poetry](https://github.com/python-poetry/poetry) lock files.
The major difference to pip rules in [rules_python](https://github.com/bazelbuild/rules_python) is that Python packages are installed as `py_library` targets and not as external repositories.
This allows to use platform information of resolved Python toolchains and build cross-platform Python artifacts.


## Getting started

To import `rules_poetry` in your project, you first need to add it to your `MODULE.bazel` file

```python
bazel_dep(name = "rules_python", version = "0.20.0")
python = use_extension("@rules_python//python:extensions.bzl", "python")
python.toolchain(
    name = "python3_11",
    python_version = "3.11",
)
use_repo(python, "python3_11")
use_repo(python, "python3_11_toolchains")

register_toolchains("@python3_9_toolchains//:all")

bazel_dep(name = "rules_poetry", version = "0.0.0")
git_override(
    module_name = "rules_poetry",
    commit = "89e1d3382c293f9f0bd6bc5ca03b9172081976d2",
    remote = "https://github.com/oxidase/rules_poetry.git",
)

poetry = use_extension("@rules_poetry//python:extensions.bzl", "poetry")
poetry.parse(
    name = "poetry",
    lock = "@//path/to:poetry.lock",
)
use_repo(poetry, "poetry")
```

and Python dependencies can be used as

```python
py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        "@poetry//:package"
    ]
)
```
