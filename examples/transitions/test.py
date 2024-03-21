import json
import os
import pathlib
import platform
import re
import struct
import subprocess
import sys
import zipfile

import pytest
from elftools.elf.elffile import ELFFile


@pytest.mark.parametrize("zip_name, arch", [("deploy_linux_arm64.zip", "AArch64"), ("deploy_linux_x86_64.zip", "x64")])
def test_elf_dynamic_libraries_in_deployment_zip(zip_name, arch):
    dynamic_libraries_re = re.compile(".*\\.so$")
    dynamic_libraries = []
    with zipfile.ZipFile(zip_name) as zip_file:
        for dynamic_library_name in [name for name in zip_file.namelist() if dynamic_libraries_re.match(name)]:
            with zip_file.open(dynamic_library_name) as dynamic_library:
                elf = ELFFile(dynamic_library)
                assert elf.elfclass == 64
                assert elf.get_machine_arch() == arch
                dynamic_libraries.append(pathlib.Path(dynamic_library_name).name)

    for library in ["python3", "openblas", "multiarray_umath"]:
        assert any([name for name in dynamic_libraries if library in name])


def test_pe_files_in_deployment_zip():
    files_re, files = re.compile(".*\\.(dll|exe|pyd)$"), []
    with zipfile.ZipFile("deploy_win32_x86_64.zip") as zip_file:
        for file_name in [name for name in zip_file.namelist() if files_re.match(name)]:
            with zip_file.open(file_name) as zipped_file:
                data = zipped_file.read()
            assert data[0:2] == b"MZ"
            (offset,) = struct.unpack("<I", data[0x3C:0x40])
            assert data[offset : offset + 4] == b"PE\x00\x00"
            (machine_type,) = struct.unpack("<H", data[offset + 4 : offset + 6])
            assert machine_type in {0x14C, 0x8664, 0xAA64}
            files.append(pathlib.Path(file_name).name)

    for name_part in ["python.exe", "python3.dll", "openblas", "multiarray_umath"]:
        assert any([name for name in files if name_part in name])


@pytest.mark.parametrize("name", ["deploy_linux_arm64", "deploy_linux_x86_64"])
def test_python_path(name):
    with zipfile.ZipFile(name + ".zip") as zip_file:
        zipped_names = zip_file.namelist()

    deployment_environment = json.load(open(name + ".json"))
    assert "environment" in deployment_environment
    assert "PYTHONPATH" in deployment_environment["environment"]

    python_paths = deployment_environment["environment"]["PYTHONPATH"].split(os.pathsep)
    assert python_paths

    for path in python_paths:
        assert any(name for name in zipped_names if path in name)

    assert "__main__.py" in zipped_names


@pytest.mark.parametrize("zip_name", ["default.zip", "host.zip", f"deploy_{sys.platform}_{platform.machine()}.zip"])
def test_python_zip(zip_name):
    zip_path = pathlib.Path(zip_name)
    if not zip_name.startswith("deploy_") or zip_path.exists():
        result = subprocess.run([sys.executable, os.fspath(zip_path.resolve())], stdout=subprocess.PIPE)
        assert result.returncode == 0

        stdout = result.stdout.decode()
        assert "module 'numpy'" in stdout
        assert "/bin/python3" in stdout


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
