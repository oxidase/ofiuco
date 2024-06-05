import sys
import tomllib

import pytest

import llama_cpp


def test_llama_version():
    dependencies = tomllib.load(open("poetry.lock", "rb"))
    locked = next((package for package in dependencies["package"] if package["name"] == "llama-cpp-python"), None)
    assert locked["version"] == llama_cpp.version.__version__

    assert llama_cpp.llama_max_devices() > 0


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
