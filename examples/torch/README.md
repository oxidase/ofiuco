# Torch example

This example shows how to use rules_poetry to fetch external dependencies from a pyproject.toml file
using PyPI repository and a direct URL as
```
torch = [
  {platform = "darwin", version = "2.2.1", source="pypi"},
  {platform = "linux", url = "https://download.pytorch.org/whl/cu121/torch-2.2.1%2Bcu121-cp312-cp312-linux_x86_64.whl"},
]
```

To have correctly loaded dynamic libraries a virtual environment has to be created as
```
py_venv(
    name = "torch_venv",
    visibility = ["//visibility:public"],
    deps = [
        "@poetry//:torch",
    ],
)
```
which can be used as a dependency ":torch_venv". Internally `py_venv` target creates a directory with symbolic links to dependencies:
```
 ls bazel-bin/venv/torch_venv/nvidia/
__init__.py  cublas  cuda_cupti  cuda_nvrtc  cuda_runtime  cudnn  cufft  curand  cusolver  cusparse  nccl  nvjitlink  nvtx

 ls -l bazel-bin/venv/torch_venv/nvidia/cudnn/lib/
total 32
lrwxrwxrwx 1 test test 128 Mar 25 10:31 __init__.py -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/__init__.py
lrwxrwxrwx 1 test test 130 Mar 25 10:31 libcudnn.so.8 -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/libcudnn.so.8
lrwxrwxrwx 1 test test 140 Mar 25 10:31 libcudnn_adv_infer.so.8 -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/libcudnn_adv_infer.so.8
lrwxrwxrwx 1 test test 140 Mar 25 10:31 libcudnn_adv_train.so.8 -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/libcudnn_adv_train.so.8
lrwxrwxrwx 1 test test 140 Mar 25 10:31 libcudnn_cnn_infer.so.8 -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/libcudnn_cnn_infer.so.8
lrwxrwxrwx 1 test test 140 Mar 25 10:31 libcudnn_cnn_train.so.8 -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/libcudnn_cnn_train.so.8
lrwxrwxrwx 1 test test 140 Mar 25 10:31 libcudnn_ops_infer.so.8 -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/libcudnn_ops_infer.so.8
lrwxrwxrwx 1 test test 140 Mar 25 10:31 libcudnn_ops_train.so.8 -> ../../../../../external/rules_poetry~~poetry~poetry/3.12/x86_64-unknown-linux-gnu/nvidia-cudnn-cu12/nvidia/cudnn/lib/libcudnn_ops_train.so.8
```


The `poetry.lock` file can be updated with
```
bazel run :update_lock
```
command or with a locally installed `poetry` as `poetry update`.
