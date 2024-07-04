# ⛎ Ofiuco Rules for Bazel

## Overview

The repository defines Bazel installation rules for multi-platform Python lock files.
The major difference to pip rules in [rules_python](https://github.com/bazelbuild/rules_python) is that Python packages are installed as `py_library` targets and not as external repositories.
This allows to use platform information of resolved Python toolchains and build cross-platform Python artifacts.

Minimum requirements:

* Bazel 6.x and rules_python with registered Python >= 3.11 toolchain.

## Getting started

### Import `ofiuco` as a module

To import `ofiuco` in your project, you first need to add it to your `MODULE.bazel` file

```python
bazel_dep(name = "rules_python", version = "0.33.2")

python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(python_version = "3.12")
use_repo(python, "python_3_12")

bazel_dep(name = "ofiuco", version = "0.3.7")

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
        "@poetry//:package"
    ]
)
```


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


## Use in a pre-bzlmod setup

Minimal example which uses the system Python run-time could be as in [examples/workspace/WORKSPACE](./examples/workspace/WORKSPACE).

Multi-version and multi-repository example which uses Python interpreters is in [examples/workspace_multi](./examples/workspace_multi/WORKSPACE) directory.
The test [`test_multiple_repos_import`](./examples/workspace_multi/test.py) checks the modules imports priority which is defined by the order of dependencies in `deps` section.
For example, in the following case
```
            [
                "@repo2//:pytest",
                "@repo1//:pytest",
            ],
```
`pytest` will be loaded from the `repo2` repository.

> **Note**
> Mixing different repositories in one `deps` block may lead to side-effects related to using incompatible versions of transitive dependencies.
