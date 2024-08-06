import sys
import tomllib

import pytest

import evdev
import llama_cpp
from llama_cpp.llama_cpp import _lib as llama_lib
from llama_cpp.llama_cpp import _lib_base_name as lib_base_name
from llama_cpp.llama_cpp import _load_shared_library as load_shared_library


def test_llama_version():
    dependencies = tomllib.load(open("poetry.lock", "rb"))
    locked = next((package for package in dependencies["package"] if package["name"] == "llama-cpp-python"), None)
    assert locked["version"] == llama_cpp.__version__

    assert llama_cpp.llama_max_devices() > 0


def test_llama_library_rpath():
    assert llama_lib
    lib = load_shared_library(lib_base_name)
    assert llama_lib._name == lib._name
    with open(lib._name, "rb") as handle:
        assert b"bazel-out/" in handle.read()


def test_evdev():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    for device in devices:
        print(device.path, device.name, device.phys)

    assert len(evdev.list_devices()) > 0


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
