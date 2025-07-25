import contextlib
import io
import json
import os
import re
import tempfile
import unittest

from python.private.lock_parser import find_unique_name, main


class TestInstallSubcommand(unittest.TestCase):
    tmpdir = os.environ.get("TEST_TMPDIR", tempfile.gettempdir())
    assets = "python/private/assets/{}/poetry.lock"
    sphinx_lock = assets.format("sphinx")

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
            main([self.assets.format("torch")])
            build_file = buffer.getvalue()

        assert build_file.count('name = "torch"') == 1
        assert build_file.count('name = "torch@2.7.0"') == 1
        assert build_file.count('name = "torch@2.7.0+cu118"') == 1
        assert build_file.count('":torch@2.7.0"') == 1
        assert build_file.count('":torch@2.7.0+cu118"') == 1

    def test_airflow_lock(self):
        """
            //:test
            @@ofiuco++poetry+poetry//:apache-airflow
            @@ofiuco++poetry+poetry//:apache-airflow
            @@ofiuco++poetry+poetry//:apache-airflow@3.0.1
        .-> @@ofiuco++poetry+poetry//:apache-airflow-task-sdk
        |   @@ofiuco++poetry+poetry//:apache-airflow-core
        `-- @@ofiuco++poetry+poetry//:apache-airflow-task-sdk
        """
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.assets.format("airflow")])
            build_file = buffer.getvalue()

        assert re.search(r'deps\s*=\s*\[\s*":apache-airflow@2.7.2",\s*":apache-airflow@3.0.1",\s*]', build_file)
        assert build_file.count(":apache-airflow-core") == 2, f"{build_file.count(':apache-airflow-core') = }"
        assert build_file.count(":apache-airflow-task-sdk") == 3, f"{build_file.count(':apache-airflow-task-sdk') = }"

    def test_find_unique_name(self):
        assert find_unique_name(["a", "b", "b", "c"], "d") == "d"
        assert find_unique_name(["a", "b", "b", "c"], "b") == "_b"
        assert find_unique_name(["a", "b", "_b", "c"], "_b") == "__b"


if __name__ == "__main__":
    unittest.main()
