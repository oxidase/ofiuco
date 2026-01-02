import os
import sys
import tomllib

import pytest


@pytest.mark.skipif(sys.platform in {"win32"}, reason="compilation is slow")
def test_llama_version():
    import llama_cpp

    with open("poetry.lock", "rb") as poetry_lock:
        dependencies = tomllib.load(poetry_lock)
    locked = next((package for package in dependencies["package"] if package["name"] == "llama-cpp-python"), None)
    assert locked["version"] == llama_cpp.__version__

    assert llama_cpp.llama_max_devices() > 0


@pytest.mark.skipif(sys.platform in {"win32"}, reason="compilation is slow")
def test_llama_library_rpath():
    from llama_cpp.llama_cpp import _base_path as base_path
    from llama_cpp.llama_cpp import _lib as llama_lib
    from llama_cpp.llama_cpp import _lib_base_name as lib_base_name
    from llama_cpp.llama_cpp import load_shared_library

    lib = load_shared_library(lib_base_name, base_path)
    assert llama_lib._name == lib._name
    with open(lib._name, "rb") as handle:
        assert b"llama_model_size" in handle.read()


@pytest.mark.skipif(sys.platform not in {"linux", "linux2"}, reason="evdev requires Linux platform")
def test_evdev():
    import evdev

    assert evdev


@pytest.mark.skipif(sys.platform in {"win32"}, reason="libpq is not installed")
def test_psycopg():
    os.environ["DYLD_LIBRARY_PATH"] = "/opt/homebrew/opt/libpq/lib"

    import psycopg

    assert psycopg


def test_radix():
    import win_inet_pton

    assert win_inet_pton

    import radix

    rtree = radix.Radix()
    rnode = rtree.add("10.0.0.0/8")
    rnode.data["blah"] = "whatever you want"

    assert rtree.search_exact("10.0.0.0/8").data["blah"] == "whatever you want"


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
