import os
import sys
import tomllib

import pytest

import torch

print(sys.platform)


def test_torch_version():
    dependencies = tomllib.load(open("poetry.lock", "rb"))
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


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
