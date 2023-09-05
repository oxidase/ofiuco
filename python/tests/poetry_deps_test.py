import glob
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from platform import python_version_tuple

import python.poetry_deps as main

TEST_TMPDIR = os.environ.get("TEST_TMPDIR", "/tmp")


def get_python_version():
    return ".".join(python_version_tuple()[:2])


# TODO: add mocking six download
class InstallArgs:
    input = "python/tests/resources/six-1.16.0-py2.py3-none-any.whl"
    output = None
    platform = None
    python_version = get_python_version()
    files = (
        """{"six-1.16.0-py2.py3-none-any.whl": """
        + """"sha256:8abb2f1d86890a2dfb989f9a77cfcfd3e47c2a354b01111771326f8aa26e0254"}"""
    )


class TestInstallSubcommand(unittest.TestCase):
    def test_install_from_file(self):
        args = InstallArgs()
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as output_dir:
            args.output = Path(output_dir)

            retcode = main.install(args)
            self.assertEqual(retcode, 0)

            wheels = glob.glob(f"{args.output}/six*")
            self.assertGreater(len(wheels), 0)

    def test_install_from_directory(self):
        args = InstallArgs()
        input_file = args.input
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as output_dir:
            args.output = Path(output_dir)

            with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.input:
                shutil.copyfile(input_file, f"{args.input}/{Path(input_file).name}")
                retcode = main.install(args)
                self.assertEqual(retcode, 0)

                wheels = glob.glob(f"{args.output}/six*")
                self.assertGreater(len(wheels), 0)

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
        args.files = f"""{{"{files.pop()}":"sha256:x"}}"""
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            assert main.install(args) != 0

    def test_wrong_files_keys(self):
        args = InstallArgs()
        list(json.loads(args.files).keys())
        args.input = "six==1.16.0"
        args.files = """{"x":"sha256:x"}"""
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            assert main.install(args) != 0

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
            retcode = main.install(args)
            self.assertEqual(retcode, 1)


if __name__ == "__main__":
    unittest.main()
