import os
import sys
import tomllib

import pendulum
import pytest

# Monkey-patch pendulum.tz.timezone to be a function for airflow v2 and a module for airflow v3
UTC = pendulum.tz.timezone.UTC
pendulum.tz.timezone = lambda _: UTC
pendulum.tz.timezone.UTC = UTC


def test_airflow_version():
    base_dir = os.environ.get("TEST_TMPDIR", "/tmp")

    os.environ["AIRFLOW_HOME"] = base_dir
    os.environ["AIRFLOW__LOGGING__BASE_LOG_FOLDER"] = base_dir

    from airflow.version import version  # noqa: E402

    with open("lock/uv.lock", "rb") as poetry_lock:
        dependencies = tomllib.load(poetry_lock)

    locked_version = next((package for package in dependencies["package"] if package["name"] == "apache-airflow"), None)
    assert locked_version
    assert locked_version["version"] == version


@pytest.mark.skipif(os.name == "nt", reason="@abseil-cpp+//absl/base building fails")
@pytest.mark.skipif(sys.version_info.minor != 13, reason="TODO: make version-independent")
def test_re2():
    print(os.getcwd())
    import re2

    assert re2


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv + ["-W", "ignore::DeprecationWarning"]))
