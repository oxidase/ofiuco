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


class DownloadArgs:
    constraint = "six==1.16.0"
    output = None
    platform = None
    python_version = get_python_version()
    source_url = None
    files = (
        """{"six-1.16.0-py2.py3-none-any.whl": """
        + """"sha256:8abb2f1d86890a2dfb989f9a77cfcfd3e47c2a354b01111771326f8aa26e0254"}"""
    )


class TestDownloadSubcommand(unittest.TestCase):
    # TODO: add mocking six download
    def test_download(self):
        args = DownloadArgs()
        for args.platform in (None, ["any"]):
            with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
                retcode = main.download(args)
                self.assertEqual(retcode, 0)

                wheels = glob.glob(f"{args.output}/*.whl")
                self.assertEqual(len(wheels), 1)

    def test_no_download_with_source_url(self):
        args = DownloadArgs()
        args.source_url = "/x"
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            retcode = main.download(args)
            self.assertEqual(retcode, 0)

            wheels = glob.glob(f"{args.output}/*")
            self.assertEqual(len(wheels), 0)

    def test_wrong_python_version(self):
        args = DownloadArgs()
        args.python_version = "x"
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            with self.assertRaisesRegex(SystemExit, "^2$"):
                main.download(args)

    def test_wrong_files_keys(self):
        args = DownloadArgs()
        files = list(json.loads(args.files).keys())
        args.files = """{"x":"sha256:x"}"""
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            with self.assertRaisesRegex(KeyError, files.pop()):
                main.download(args)

    def test_wrong_files_hash(self):
        args = DownloadArgs()
        files = list(json.loads(args.files).keys())
        args.files = f"""{{"{files.pop()}":"sha256:x"}}"""
        with tempfile.TemporaryDirectory(prefix=f"{TEST_TMPDIR}/") as args.output:
            with self.assertRaisesRegex(RuntimeError, "expected x"):
                main.download(args)


class InstallArgs:
    kind = "wheel"
    input = "python/tests/resources/six-1.16.0-py2.py3-none-any.whl"
    output = None
    platform = None
    python_version = get_python_version()


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


if __name__ == "__main__":
    unittest.main()
