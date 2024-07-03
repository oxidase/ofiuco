import inspect
import os
import platform
import sys

import pytest

first, second = os.environ["PYTEST_ORDER"]
first_repo = f"/poetry_repo{first}/"
second_repo = f"/poetry_repo{second}/"


def test_multiple_repos_import():
    pytest_path = inspect.getfile(pytest)
    assert first_repo in pytest_path
    assert second_repo not in pytest_path


def test_order_in_sys_path():
    first_repo_max = max([index for index, path in enumerate(sys.path) if first_repo in path])
    second_repo_min = min([index for index, path in enumerate(sys.path) if second_repo in path])
    assert first_repo_max < second_repo_min


def test_version_tag():
    version = ".".join(platform.python_version_tuple()[:2])
    assert f"/{version}/" in inspect.getfile(pytest)


def test_conditional_dependency():
    """pytest has dependency 'exceptiongroup = {... markers = "python_version < \"3.11\""}'"""
    is_required = int(platform.python_version_tuple()[1]) < 11
    try:
        import exceptiongroup
    except ImportError:
        is_installed = False
    else:
        is_installed = True

    assert is_installed == is_required


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
