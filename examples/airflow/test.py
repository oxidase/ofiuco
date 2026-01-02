import os
import sys
import tomllib

import pytest


def test_airflow_version():
    v = sys.version_info
    base_dir = os.environ.get("TEST_TMPDIR", "/tmp") + f"/{v.major}_{v.minor}_{v.micro}"
    os.makedirs(base_dir, exist_ok=True)

    os.environ["AIRFLOW_HOME"] = base_dir
    os.environ["AIRFLOW__LOGGING__BASE_LOG_FOLDER"] = base_dir

    from airflow.version import version  # noqa: E402

    with open("lock/uv.lock", "rb") as poetry_lock:
        dependencies = tomllib.load(poetry_lock)

    locked_version = next((package for package in dependencies["package"] if package["name"] == "apache-airflow"), None)
    assert locked_version
    assert locked_version["version"] == version


@pytest.mark.skipif(os.name == "nt", reason="@abseil-cpp+//absl/base building fails")
def test_re2():
    import re2

    text = "email=test@example.com"
    pattern = re2.compile(r"(\w+)@(\w+\.\w+)")

    assert (m := pattern.search(text))
    assert m.group(1) == "test"
    assert m.group(2) == "example.com"


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv + ["-W", "ignore::DeprecationWarning"]))
