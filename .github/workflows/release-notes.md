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
