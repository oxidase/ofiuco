import sys
import tomllib

import pendulum
import pytest
from packaging.markers import Marker

# Monkey-patch pendulum.tz.timezone to be a function for airflow v2 and a module for airflow v3
UTC = pendulum.tz.timezone.UTC
pendulum.tz.timezone = lambda _: UTC
pendulum.tz.timezone.UTC = UTC

from airflow.version import version  # noqa: E402


def test_airflow_version():
    with open("lock/poetry.lock", "rb") as poetry_lock:
        dependencies = tomllib.load(poetry_lock)
    locked_version = next(
        (
            package
            for package in dependencies["package"]
            if package["name"] == "apache-airflow" and Marker(package["markers"]).evaluate()
        ),
        None,
    )
    assert locked_version
    assert locked_version["version"] == version


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
