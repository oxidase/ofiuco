import glob
import json
import os
import tempfile
import unittest
from pathlib import Path
from platform import python_version_tuple
from unittest.mock import patch

import python.private.poetry_deps as main

TEST_TMPDIR = os.environ.get("TEST_TMPDIR", "/tmp")


def get_python_version():
    return ".".join(python_version_tuple()[:2])


# TODO: add mocking six download
class InstallArgs:
    input = "python/private/assets/six-1.16.0-py2.py3-none-any.whl"
    output = None
    platform = None
    python_version = get_python_version()
    files = (
        """{"six-1.16.0-py2.py3-none-any.whl": """
        + """"sha256:8abb2f1d86890a2dfb989f9a77cfcfd3e47c2a354b01111771326f8aa26e0254"}"""
    )
    source = ""
    develop = False
    cc_toolchain = None
    entry_points = None


class TestInstallSubcommand(unittest.TestCase):
    def test_install_from_file(self):
        args = InstallArgs()
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as output_dir:
            args.output = Path(output_dir)
            args.entry_points = Path(output_dir) / ".dist_info/entry_points.txt"

            retcode = main.install(args)
            self.assertEqual(retcode, 0)

            wheels = glob.glob(f"{args.output}/six*")
            self.assertGreater(len(wheels), 0)

            self.assertTrue(args.entry_points.exists())

    def test_install_from_url(self):
        args = InstallArgs()
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as output_dir:
            args.output = Path(output_dir)

            args.kind = "url"
            retcode = main.install(args)
            self.assertEqual(retcode, 0)

            wheels = glob.glob(f"{args.output}/six*")
            self.assertGreater(len(wheels), 0)

    def test_wrong_files_hash(self):
        args = InstallArgs()
        files = list(json.loads(args.files).keys())
        args.input = "six==1.16.0"
        args.files = f"""{{"{files.pop()}":"sha256:invalid_hash"}}"""
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            assert main.install(args) != 0

    def test_wrong_files_keys(self):
        args = InstallArgs()
        list(json.loads(args.files).keys())
        args.input = "six==1.16.0"
        args.files = """{"x":"sha256:8abb2f1d86890a2dfb989f9a77cfcfd3e47c2a354b01111771326f8aa26e0254"}"""
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            assert main.install(args) == 0

    def test_wrong_python_version(self):
        args = InstallArgs()
        args.python_version = "x"
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            with self.assertRaisesRegex(SystemExit, "^2$"):
                main.install(args)

    def test_no_download_with_source_url(self):
        args = InstallArgs()
        args.input = "/x"
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            assert main.install(args) != 0

    def test_extra_index_url(self):
        args = InstallArgs()
        args.input = "torchaudio==2.0.0"
        args.platform = ["linux_x86_64"]
        args.index = ["https://download.pytorch.org/whl/cu118"]
        args.python_version = "3.11"
        args.files = (
            """{"torchaudio-2.0.0_cu118-cp311-cp311-linux_x86_64.whl": """
            + """"e700907139ae40ad8de4623e54b22c6f910d5ae51a5257c024d6a654ab83baea"}"""
        )

        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            assert main.install(args) != 0

    def test_source_urls(self):
        args = InstallArgs()
        args.input = "torch==2.1.0.dev20230902"
        args.platform = ["linux_x86_64"]
        args.index = ["https://download.pytorch.org/whl/cu118"]
        args.python_version = "3.11"
        args.source_url = [
            "https://download.pytorch.org/whl/nightly/cpu/torch-2.1.0.dev20230902-cp311-none-macosx_11_0_arm64.whl",
            "https://download.pytorch.org/whl/nightly/cu121/torch-2.1.0.dev20230902%2Bcu121-cp311-cp311-linux_x86_64.whl",
        ]

        class InstallCommand:
            def __init__(self, *args, **kwargs):
                pass

            def main(self, args):
                requirements_file = args[args.index("-r") + 1]
                with open(requirements_file) as requirements_obj:
                    requirements = requirements_obj.read()
                print(requirements)
                assert "torch==2.1.0.dev20230902" in requirements
                assert "macosx_11_0_arm64" not in requirements

        with patch("pip._internal.commands.install.InstallCommand", InstallCommand):
            with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
                retcode = main.install(args)
                self.assertEqual(retcode, 0)

    def test_get_data(self):
        args = InstallArgs()
        args.cc_toolchain = json.dumps(
            dict(
                CC="CC",
                CXX="CXX",
                LD="LD",
                CXXFLAGS=["-I.", "-Ix", "-I/x"],
                compiler_executable="compiler_executable",
                dynamic_runtime_solib_dir=".",
                built_in_include_directories=[".", "x", "/x"],
                compiler="clang",
                cpu="darwin_arm64",
            )
        )

        class InstallCommand:
            def __init__(self, *args, **kwargs):
                pass

            def main(self, args):
                assert "CC" in os.environ
                assert "CFLAGS" in os.environ
                assert "LDFLAGS" in os.environ
                assert "CMAKE_ARGS" in os.environ
                assert "AR" not in os.environ

                assert Path(os.environ["CC"]).is_absolute()
                assert os.environ["ASMFLAGS"] == os.environ["ASFLAGS"]
                assert os.environ["ASMFLAGS"] == "-arch arm64"
                assert os.environ["CFLAGS"] == "-arch arm64"
                assert os.environ["CXXFLAGS"] == "-arch arm64 -I. -Ix -I/x"
                assert os.environ["LDFLAGS"] == "-Wl,-rpath,."
                assert "Darwin" in os.environ["CMAKE_ARGS"]

                return 42

        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as output_dir:
            args.output = Path(output_dir)

            with patch("pip._internal.commands.install.InstallCommand", InstallCommand):
                retcode = main.install(args)
                self.assertEqual(retcode, 42)

    def test_filter_cxx_builtin_include_directories(self):
        cflags = [
            "-U_FORTIFY_SOURCE",
            "-fstack-protector",
            "-Wall",
            "-Wthread-safety",
            "-Wself-assign",
            "-Wunused-but-set-parameter",
            "-Wno-free-nonheap-object",
            "-fcolor-diagnostics",
            "-fno-omit-frame-pointer",
            "-fPIC",
            "-I/usr/local/include",
            "-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1",
            "-I/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/16/include",
            "-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include",
            "-I/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include",
            "-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks",
            "-I/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/16/share",
            "-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
            "-mmacosx-version-min=15.2",
            "-no-canonical-prefixes",
            "-Wno-builtin-macro-redefined",
            '-D__DATE__="redacted"',
            '-D__TIMESTAMP__="redacted"',
            '-D__TIME__="redacted"',
        ]
        self.assertEqual(len(main.filter_cxx_builtin_include_directories(cflags)), len(cflags) - 1)


if __name__ == "__main__":
    unittest.main()
