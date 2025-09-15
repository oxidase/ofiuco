import sys
import tomllib

import pytest


def test_boto3_version():
    import boto3

    with open("poetry.lock", "rb") as poetry_lock:
        dependencies = tomllib.load(poetry_lock)
    locked_boto3 = next((package for package in dependencies["package"] if package["name"] == "boto3"), None)
    assert locked_boto3
    assert locked_boto3["version"] == boto3.__version__


def test_annetbox_extra():
    import aiohttp
    import annetbox

    with pytest.raises(ModuleNotFoundError):
        import requests

        assert not requests, "annetbox[sync]"

    assert annetbox
    assert aiohttp, "annetbox[async]"


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
