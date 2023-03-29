import sys
import tomllib

import boto3
import pytest


def test_boto3_version():
    dependencies = tomllib.load(open("poetry.lock", "rb"))
    locked_boto3 = next((package for package in dependencies["package"] if package["name"] == "boto3"), None)
    assert locked_boto3
    assert locked_boto3["version"] == boto3.__version__


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
