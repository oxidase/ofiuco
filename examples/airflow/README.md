# airflow example

This example shows how to use `ofiuco` to fetch external dependencies from a pyproject.toml file
and than use in BUILD files as dependencies of Bazel targets.

The `poetry.lock` file can be updated with
```
bazel run :lock
```
command or with a locally installed `poetry` as `poetry update`.
