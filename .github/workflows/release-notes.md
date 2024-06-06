## Using Bzlmod

Add to your `MODULE.bazel` file:

```starlark
bazel_dep(name = "rules_poetry", version = "${TAG}")

poetry = use_extension("@rules_poetry//python:extensions.bzl", "poetry")
poetry.parse(
    name = "poetry",
    lock = "//:poetry.lock",
)
use_repo(poetry, "poetry")
```

## Using WORKSPACE

Paste this snippet into your `WORKSPACE` file:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_poetry",
    sha256 = "${SHA256}",
    strip_prefix = "${PREFIX}",
    url = "https://github.com/oxidase/rules_poetry/releases/download/v${TAG}/${ARCHIVE}",
)

load("@rules_poetry//python:poetry_parse.bzl", "poetry_parse")
load("@rules_poetry//python:repositories.bzl", install_poetry_dependencies = "install_dependencies")

install_poetry_dependencies()

poetry_parse(
    name = "poetry",
    lock = "//:poetry.lock",
)
```
