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
bazel_dep(name = "rules_python", version = "1.8.0-rc1")

python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(python_version = "3.13")
use_repo(python, "python_3_13")

bazel_dep(name = "ofiuco", version = "0.8.1")

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

### Building at Windows platforms


1. Install Scoop
https://github.com/ScoopInstaller/Install?tab=readme-ov-file#for-admin

```
irm get.scoop.sh -outfile 'install.ps1'
.\install.ps1 -RunAsAdmin
```

2. Install git and emacs

```
scoop install git
scoop bucket add extras
scoop install grep emacs bazelisk zip unzip python vcredist2022 WinDirStat
scoop bucket add milnak https://github.com/milnak/scoop-bucket
scoop install milnak/windbg
```

3. Instal VisualStudio build tools

```
# Source - https://stackoverflow.com/a
# Posted by caiohamamura, modified by community. See post 'Timeline' for change history
# Retrieved 2025-12-31, License - CC BY-SA 4.0

winget install Microsoft.VisualStudio.2022.BuildTools --force --override "--wait --passive --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK"
```

4. Set Python files associations
cmd /c assoc .py=Python.File
cmd /c assoc .pyz=Python.File
cmd /c ftype Python.File="C:\\Users\\Administrator\\scoop\\apps\\python\\current\\python.exe" "%1" %*

winget install Microsoft.VisualStudio.2022.BuildTools

5. Checkout ofiuco

git clone git://oxidase@github.com/oxidase/ofiuco/
cd ofiuco
bazelisk test //...
