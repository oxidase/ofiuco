# ⛎ Ofiuco Rules for Bazel

## Overview

The repository defines Bazel installation rules for multi-platform Python lock files.
The major difference to pip rules in [rules_python](https://github.com/bazelbuild/rules_python) is that Python packages are installed as `py_library` targets and not as external repositories.
This allows to use platform information of resolved Python toolchains and build cross-platform Python artifacts.

Minimum requirements:

* Bazel 8.x and rules_python with registered Python >= 3.11 toolchain.

## Getting started

### Import `ofiuco` as a module

To import `ofiuco` in your project, you first need to add it to your `MODULE.bazel` file

```python
bazel_dep(name = "rules_python", version = "1.6.1")

python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(python_version = "3.13")
use_repo(python, "python_3_13")

bazel_dep(name = "ofiuco", version = "0.5.3")

poetry = use_extension("@ofiuco//python:extensions.bzl", "poetry")
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
        "@poetry//:package1",
        "@poetry//:package2",
    ]
)
```
or to include all Python dependencies you can use `:all` synthetic target as
```python
py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        "@poetry//:all",
    ]
)
```

If `all` is a legit package name then the synthetic target will have one or more underscores to disambiguate names.


### Update lock files

A lock file in the workspace can be updated using a host Python interpreter as
```
python3 -m pip install poetry

poetry update
```

or using a pre-defined target
```
load("@ofiuco//python:poetry.bzl", "poetry_update")

poetry_update(
    name = "update_lock",
    toml = "pyproject.toml",
    lock = "poetry.lock",
)
```

In both cases the host interpreter is used in the latter case poetry package with dependencies is installed as an external repository.

### Update uv.lock.json

```
cargo install --git https://github.com/bazel-contrib/multitool
fish_add_path $HOME/.cargo/bin

multitool --lockfile python/private/uv.lock.json update
```
