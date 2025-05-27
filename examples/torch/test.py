import os
import sys
import tomllib

import pytest

import colorama
import sample_package
import torch
import torchvision

LOCK_FILE = "gen/poetry.lock"


def test_sample_package():
    assert "Hello" in sample_package.hello()


def test_torch_version():
    dependencies = tomllib.load(open(LOCK_FILE, "rb"))
    locked_torch = [package for package in dependencies["package"] if package["name"] == "torch"]
    assert len(locked_torch) == 2
    assert torch.__version__ in set(package["version"] for package in locked_torch)


@pytest.mark.skipif(sys.platform != "linux", reason="torch+CUDA is installed only for linux")
def test_cuda_libs_loaded():
    assert torch.backends.cudnn.enabled
    assert torch.backends.cudnn.version() > 8000
    with open(f"/proc/{os.getpid()}/maps") as maps:
        memory_mapping = maps.read()
    assert "torch/lib/libtorch_cuda.so" in memory_mapping
    assert "nvidia/cuda_runtime/lib/libcudart.so.12" in memory_mapping
    assert "nvidia/cuda_cupti/lib/libcupti.so.12" in memory_mapping
    assert "nvidia/cudnn/lib/libcudnn.so.8" in memory_mapping


def test_torchvision_version():
    dependencies = tomllib.load(open(LOCK_FILE, "rb"))
    packages = [
        package
        for package in dependencies["package"]
        if package["name"] == "torchvision" and eval(package.get("markers", ""), {}, {"sys_platform": sys.platform})
    ]
    assert len(packages) == 1
    assert torchvision.__version__ == packages[0]["version"]


def test_colorama_version():
    assert "dev" in colorama.__version__


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
