import sys
import tomllib
from pathlib import Path
from zipfile import ZipFile

import pytest


def test_app_wheel():
    wheel = Path("app-0.0.1-py3-none-any.whl")
    assert wheel.exists()

    with ZipFile(wheel) as zf:
        metadata_file = next(n for n in zf.namelist() if n.endswith("/METADATA"))
        metadata = zf.read(metadata_file).decode("utf-8").splitlines()

    with open("poetry.lock", "rb") as poetry_lock:
        dependencies = tomllib.load(poetry_lock)
        locked_deps = {p["name"]: p["version"] for p in dependencies["package"]}

    assert {
        f"Requires-Dist: urllib3=={locked_deps['urllib3']}",
        f"Requires-Dist: requests=={locked_deps['requests']}",
    }.issubset(set(metadata))


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
