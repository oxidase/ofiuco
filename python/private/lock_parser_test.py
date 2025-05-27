import contextlib
import io
import json
import os
import tempfile
import unittest

from python.private.lock_parser import main


class TestInstallSubcommand(unittest.TestCase):
    tmpdir = os.environ.get("TEST_TMPDIR", tempfile.gettempdir())
    sphinx_lock = "python/private/assets/sphinx/poetry.lock"
    torch_lock = "python/private/assets/torch/poetry.lock"

    def test_empty_args(self):
        with self.assertRaises(SystemExit):
            main([])

    def test_sphinx_lock(self):
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.sphinx_lock, "--nogenerate_extras", f"--project_file={self.sphinx_lock}"])
            build_file = buffer.getvalue()

        assert r'constraint = "zstandard==0.23.0"' in build_file
        assert (
            r"zstandard-0.23.0-cp312-cp312-manylinux_2_5_i686.manylinux1_i686.manylinux_2_17_i686.manylinux2014_i686.whl"
            in build_file
        )
        assert r"sha256:53dd9d5e3d29f95acd5de6802e909ada8d8d8cfa37a3ac64836f3bc4bc5512db" in build_file
        assert r'{"cffi": "platform_python_implementation == \\\"PyPy\\\""}' in build_file

    def test_sphinx_platforms(self):
        platforms = json.dumps({"a": "b"})
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.sphinx_lock, platforms])
            build_file = buffer.getvalue()

        assert "\"a\": '''b'''" in build_file

    def test_sphinx_extras(self):
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.sphinx_lock, "--generate_extras"])
            build_file = buffer.getvalue()

        assert r'{"cffi": "platform_python_implementation == \\\"PyPy\\\""}' in build_file

    def test_torch_lock(self):
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.torch_lock])
            build_file = buffer.getvalue()

        assert build_file.count('name = "torch"') == 1
        assert build_file.count('name = "torch@2.7.0"') == 1
        assert build_file.count('name = "torch@2.7.0+cu118"') == 1
        assert build_file.count('":torch@2.7.0"') == 1
        assert build_file.count('":torch@2.7.0+cu118"') == 1


if __name__ == "__main__":
    unittest.main()
