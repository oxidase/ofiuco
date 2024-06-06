import hashlib
import inspect
import shutil
import sys
from pathlib import Path

import pytest


def test_repos():
    pytest_path = inspect.getfile(pytest)
    assert "/poetry/" in pytest_path


def test_sys_path():
    poetry_repo = [index for index, path in enumerate(sys.path) if "/poetry/" in path]
    assert poetry_repo


def test_host_binary_path():
    def hash(path):
        return hashlib.sha256(open(sys.executable, "rb").read()).hexdigest()

    process_binary = Path(sys.executable)
    host_binary = shutil.which(process_binary.name)
    assert hash(process_binary) == hash(host_binary)


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
