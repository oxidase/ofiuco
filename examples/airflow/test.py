import sys

import pytest

print(sys.path)
# from airflow.sdk import DAG
# import tomllib


# def test_boto3_version():
#     with open("poetry.lock", "rb") as poetry_lock:
#         dependencies = tomllib.load(poetry_lock)
#     locked_boto3 = next(
#         (package for package in dependencies["package"] if package["name"] == "boto3"),
#         None,
#     )
#     assert locked_boto3
#     assert locked_boto3["version"] == boto3.__version__


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
