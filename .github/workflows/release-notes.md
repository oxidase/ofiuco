## Using Bzlmod

Add to your `MODULE.bazel` file:

* for packaging and dependency management with [Poetry](https://python-poetry.org/)

```starlark
bazel_dep(name = "ofiuco", version = "${TAG}")

poetry = use_extension("@ofiuco//python:extensions.bzl", "poetry")
poetry.parse(
    name = "poetry",
    lock = "//:poetry.lock",
)
use_repo(poetry, "poetry")
```


## Using WORKSPACE

Paste this snippet into your `WORKSPACE` file:

* for packaging and dependency management with [Poetry](https://python-poetry.org/)

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

toolchain_name = "python"
python_version = "3.13"

# Setup rules_python
http_archive(
    name = "rules_python",
    sha256 = "${RULES_PYTHON_SHA256}",
    strip_prefix = "rules_python-${RULES_PYTHON_TAG}",
    url = "${RULES_PYTHON_URL}",
)

load("@rules_python//python:repositories.bzl", "py_repositories", "python_register_toolchains")

py_repositories()

python_register_toolchains(toolchain_name, python_version)

# Setup ofiuco
http_archive(
    name = "ofiuco",
    sha256 = "${SHA256}",
    strip_prefix = "${PREFIX}",
    url = "https://github.com/oxidase/ofiuco/releases/download/v${TAG}/${ARCHIVE}",
)

load("@ofiuco//python:repositories.bzl", install_poetry_dependencies = "install_dependencies")

install_poetry_dependencies(toolchain_name, python_version)

load("@ofiuco//python:poetry_parse.bzl", "poetry_parse")

poetry_parse(
    name = "poetry",
    lock = "//:poetry.lock",
)
```
