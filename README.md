# Python Poetry Rules for Bazel

## Overview

The repository defines Bazel installation rules for [Poetry](https://github.com/python-poetry/poetry) lock files.
The major difference to pip rules in [rules_python](https://github.com/bazelbuild/rules_python) is that Python packages are installed as `py_library` targets and not as external repositories.
This allows to use platform information of resolved Python toolchains and build cross-platform Python artifacts.


## Getting started

### Import `rules_poetry` as a module

To import `rules_poetry` in your project, you first need to add it to your `MODULE.bazel` file

```python
bazel_dep(name = "rules_python", version = "0.31.0")

python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(python_version = "3.12")
use_repo(python, "python_3_12")

bazel_dep(name = "rules_poetry", version = "0.3.1")

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


### Update lock files

A lock file in the workspace can be updated using a host Python interpreter as
```
python3 -m pip install poetry

poetry update
```

or using a pre-defined target
```
load("@rules_poetry//python:poetry.bzl", "poetry_update")

poetry_update(
    name = "update_lock",
    toml = "pyproject.toml",
    lock = "poetry.lock",
)
```

In both cases the host interpreter is used in the latter case poetry package with dependencies is installed as an external repository.
