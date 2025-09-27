# ⛎ Ofiuco Rules for Bazel

## Overview

The repository defines Bazel installation rules for multi-platform Python lock files.
The major difference to pip rules in [rules_python](https://github.com/bazelbuild/rules_python) is that Python packages are installed as `py_library` targets and not as external repositories.
This allows to use platform information of resolved Python toolchains and build cross-platform Python artifacts.

Minimum requirements:

* Bazel 8.x and rules_python with registered Python >= 3.11 toolchain.

## Getting started

### Update lock files

A lock file in the workspace can be updated using a host Python interpreter as
```
python3 -m pip install poetry

poetry update
```

or using a pre-defined target
```
load("@ofiuco//python:poetry.bzl", "poetry_lock")

poetry_lock(
    name = "lock",
    toml = "pyproject.toml",
    lock = "poetry.lock",
)
```

In both cases the host interpreter is used in the latter case poetry package with dependencies is installed as an external repository.

### Import `ofiuco` as a module

To import `ofiuco` in your project, you first need to add it to your `MODULE.bazel` file

```python
bazel_dep(name = "rules_python", version = "1.6.1")

python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(python_version = "3.13")
use_repo(python, "python_3_13")

bazel_dep(name = "ofiuco", version = "0.6.3")

parse = use_extension("@ofiuco//python:extensions.bzl", "parse")
parse.lock(
    name = "python",
    lock = "@//path/to:poetry_or_uv.lock",
    toml = "@//path/to:pyproject.toml",
)
use_repo(parse, "python")
```

and Python dependencies can be used as

```python
py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        "@python//:package1",
        "@python//:package2",
    ]
)
```
or to include all Python dependencies you can use `:all` synthetic target as
```python
py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        "@python//:all",
    ]
)
```

If `all` is a legit package name then the synthetic target will have one or more underscores to disambiguate names.


### Update uv.lock.json

```
cargo install --git https://github.com/bazel-contrib/multitool
fish_add_path $HOME/.cargo/bin

multitool --lockfile python/private/uv.lock.json update
```
