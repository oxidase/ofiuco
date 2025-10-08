import datetime
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


def test_rust_dependencies():
    # pola-rs
    import polars as pl

    df = pl.DataFrame(
        {
            "language": ["English", "Dutch", "Portuguese", "Finish", "Ukrainian", "Thai"],
            "fruit": ["pear", "peer", "pêra", "päärynä", "груша", "ลูกแพร์"],
        }
    )

    result = df.with_columns(
        pl.col("fruit").str.len_bytes().alias("byte_count"),
        pl.col("fruit").str.len_chars().alias("letter_count"),
    )
    assert sum(result["byte_count"]) > sum(result["letter_count"])

    # Cryptography
    from cryptography.fernet import Fernet

    key = Fernet.generate_key()
    f = Fernet(key)
    message = b"A really secret message. Not for prying eyes."
    token = f.encrypt(message)
    assert f.decrypt(token) == message

    # orjson
    import numpy
    import orjson

    data = {
        "x": "y",
        "created_at": datetime.datetime(1970, 1, 1),
        "status": "🆗",
        "payload": numpy.array([[1, 2], [3, 4]]),
    }
    expected = b'{"x":"y","created_at":"1970-01-01T00:00:00+00:00","status":"\xf0\x9f\x86\x97","payload":[[1,2],[3,4]]}'
    assert orjson.dumps(data, option=orjson.OPT_NAIVE_UTC | orjson.OPT_SERIALIZE_NUMPY) == expected


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
