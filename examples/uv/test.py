import sys
import tomllib

import pytest


def test_boto3_version():
    import boto3

    with open("uv.lock", "rb") as uv_lock:
        dependencies = tomllib.load(uv_lock)
    locked_boto3 = next((package for package in dependencies["package"] if package["name"] == "boto3"), None)
    assert locked_boto3
    assert locked_boto3["version"] == boto3.__version__


def test_all_imports():
    import pip

    assert pip

    import pre_commit

    assert pre_commit

    import setuptools

    assert setuptools

    import sphinxcontrib.images as images

    assert images


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
