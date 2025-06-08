import sys
import tomllib

import pytest
from airflow.version import version
from packaging.markers import Marker


def test_airflow_version():
    with open("poetry.lock", "rb") as poetry_lock:
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
