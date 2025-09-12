# Simple example with Astral uv lock file

This example shows how to use `ofiuco` to fetch external dependencies from a pyproject.toml file
and than use in BUILD files as dependencies of Bazel targets.

The `uv.lock` file can be updated with
```
bazel run :lock
```
command or with a locally installed `uv` as `uv lock`.
