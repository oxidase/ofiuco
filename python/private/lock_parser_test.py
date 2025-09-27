import asyncio
import contextlib
import io
import json
import os
import re
import tempfile
import unittest
import unittest.mock
from pathlib import Path

import python.private.lock_parser as parser
from python.private.lock_parser import WHEEL_RE, find_unique_name, main


class TestPoetryInstallSubcommand(unittest.TestCase):
    tmpdir = os.environ.get("TEST_TMPDIR", tempfile.gettempdir())
    assets = "python/private/assets/{}/poetry.lock"
    sphinx_lock = assets.format("sphinx")

    def test_empty_args(self):
        with self.assertRaises(SystemExit):
            main([])

    def test_sphinx_files(self):
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.sphinx_lock, "--nogenerate_extras", f"--project_file={self.sphinx_lock}", "--output=files"])
            repositories = buffer.getvalue()
        assert (
            r"zstandard-0.23.0-cp312-cp312-manylinux_2_5_i686.manylinux1_i686.manylinux_2_17_i686.manylinux2014_i686.whl"
            in repositories
        )
        assert r"53dd9d5e3d29f95acd5de6802e909ada8d8d8cfa37a3ac64836f3bc4bc5512db" in repositories

    def test_sphinx_lock(self):
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.sphinx_lock, "--nogenerate_extras", f"--project_file={self.sphinx_lock}", "--output=packages"])
            build_file = buffer.getvalue()

        assert r"py2.py3-none-any" in build_file
        assert r"zstandard-0.23.0-cp310-cp310-macosx_10_9_x86_64//:whl" in build_file
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

    def test_platform_parsing(self):
        """Test against 'bazel query //python/platforms/...'"""
        tests = [
            ("MarkupSafe-3.0.2-cp310-cp310-win32", {"platform": "win32"}, "cp310-cp310-win32"),
            ("websockets-15.0.1-cp39-cp39-win_amd64", {"platform": "win_amd64"}, "cp39-cp39-win_amd64"),
            ("yarl-1.20.1-cp39-cp39-macosx_11_0_arm64", {}, "cp39-cp39-macosx_11_0_arm64"),
            ("charset_normalizer-3.4.3-cp310-cp310-macosx_10_9_universal2", {}, "cp310-cp310-macosx_10_9_universal2"),
            ("grpcio-1.74.0-cp310-cp310-linux_armv7l", {"platform": "linux_armv7l"}, "cp310-cp310-linux-armv7-glibc"),
            ("g-1-cp39-cp39-musllinux_1_1_i686", {"platform": "musllinux_1_1_i686"}, "cp39-cp39-linux-x86_32-musl"),
            ("nv_cu-12-py3-none-manylinux1_x86_64", {"platform": "manylinux1_x86_64"}, "py3-none-linux-x86_64-glibc"),
            ("x-1-cp36-cp36m-manylinux2010_x86_64.manylinux_2_12_x86_64", {}, "cp36-cp36m-linux-x86_64-glibc"),
            ("pillow-11.3.0-cp313-cp313-ios_13_0_arm64_iphoneos", {}, "cp313-cp313-ios_13_0_arm64_iphoneos"),
        ]

        for test, parts, expected in tests:
            assert (m := WHEEL_RE.fullmatch(test)), f"{test = } does not match wheel regular expression"
            assert parts.items() <= m.groupdict().items(), f"{parts} ⊄ {m.groupdict()}"
            assert (actual := parser.get_select_condition(m.groupdict())) == expected, f"'{actual}' ≠ '{expected}'"

    def test_best_package(self):
        tests = [
            ({"musllinux_1_1_aarch64": "a", "musllinux_1_2_aarch64": "b"}, {"glibc": (2, 27), "musl": (1, 2)}, "b"),
            (
                {"musllinux_1_1_aarch64.musllinux_1_2_aarch64": "a", "musllinux_1_3_aarch64": "b"},
                {"glibc": (2, 27), "musl": (1, 2)},
                "a",
            ),
            (
                {"musllinux_1_1_aarch64.musllinux_1_2_aarch64": "a", "musllinux_1_3_aarch64": "b"},
                {"glibc": (2, 27), "musl": (1, 4)},
                "b",
            ),
            (
                {"musllinux_1_1_aarch64.musllinux_1_2_aarch64": "a", "musllinux_1_3_aarch64": "b"},
                {"glibc": (2, 27), "musl": (1, 0)},
                "a",
            ),
            (
                {"manylinux_2_28_x86_64": "a", "manylinux2010_x86_64.manylinux_2_12_x86_64.manylinux_2_17_x86_64": "b"},
                {"glibc": (2, 27), "musl": (1, 2)},
                "b",
            ),
            ({"manylinux1_x86_64.manylinux2012_x86_64": "a"}, {"glibc": (2, 27), "musl": (1, 2)}, "a"),
            ({"manylinux1_x86_64.manylinux1_x86_64": "a"}, {"glibc": (2, 1), "musl": (1, 2)}, "a"),
            (
                {"manylinux_2_28_x86_64": "a", "manylinux2014_x86_64": "b", "manylinux_2_34_x86_64": "c"},
                {"glibc": (2, 31), "musl": (1, 2)},
                "a",
            ),
            (
                {"manylinux_2_28_x86_64": "a", "manylinux2014_x86_64": "b", "manylinux_2_34_x86_64": "c"},
                {"glibc": (2, 14), "musl": (1, 2)},
                "b",
            ),
            (
                {"manylinux_2_28_x86_64": "a", "manylinux2014_x86_64": "b", "manylinux_2_34_x86_64": "c"},
                {"glibc": (2, 27), "musl": (1, 2)},
                "b",
            ),
            (
                {"manylinux_2_28_x86_64": "a", "manylinux2014_x86_64": "b", "manylinux_2_34_x86_64": "c"},
                {"glibc": (2, 34), "musl": (1, 2)},
                "c",
            ),
        ]

        for index, (test, kwargs, expected) in enumerate(tests):
            assert (actual := parser.get_best_match(test, **kwargs)) == expected, f"{actual} ≠ {expected} for {index}"


class TestUvInstallSubcommand(unittest.TestCase):
    tmpdir = os.environ.get("TEST_TMPDIR", tempfile.gettempdir())
    assets = "python/private/assets/{}/uv.lock"
    sphinx_lock = assets.format("sphinx")

    def test_sphinx_files(self):
        with io.StringIO() as buffer, contextlib.redirect_stdout(buffer):
            main([self.sphinx_lock, "--nogenerate_extras", f"--project_file={self.sphinx_lock}", "--output=files"])
            repositories = buffer.getvalue()
        assert (
            r"zstandard-0.24.0-cp312-cp312-manylinux2010_i686.manylinux2014_i686.manylinux_2_12_i686.manylinux_2_17_i686.whl"
            in repositories
        ), repositories
        assert r"d2b3b4bda1a025b10fe0269369475f420177f2cb06e0f9d32c95b4873c9f80b8" in repositories, repositories


class TestLegacyIndexParsers(unittest.TestCase):
    expected = {
        "86c0d0b93306b961d58d62a4db4879f27fe25513d4b969df351abdddb3c30e01": "https://files.pythonhosted.org/packages/a3/5c/00a0e072241553e1a7496d638deababa67c5058571567b92a7eaa258397c/pytest-8.4.2.tar.gz",
        "872f880de3fc3a5bdc88a11b39c9710c3497a547cfa9320bc3c5e62fbf272e79": "https://files.pythonhosted.org/packages/a8/a4/20da314d277121d6534b3a980b29035dcd51e6744bd79075a6ce8fa4eb8d/pytest-8.4.2-py3-none-any.whl#sha256=872f880de3fc3a5bdc88a11b39c9710c3497a547cfa9320bc3c5e62fbf272e79",
    }

    @unittest.mock.patch("urllib.request.urlopen")
    def test_json(self, mock_urlopen):
        """curl -s --header 'Accept: application/vnd.pypi.simple.v1+json,text/html' https://pypi.org/simple/pytest"""
        response = unittest.mock.MagicMock()
        response.getcode.return_value = 200
        response.headers.get_content_type.return_value = parser.PYPI_SIMPLE_MIME_TYPE
        response.read.return_value = Path("python/private/assets/pytest.json").read_bytes()
        response.__enter__.return_value = response
        mock_urlopen.return_value = response

        index = asyncio.run(parser.get_simple_index("pytest", "https://pypi.org/simple/pytest"))
        assert set(self.expected.items()) & set(index.items())

    @unittest.mock.patch("urllib.request.urlopen")
    def test_html(self, mock_urlopen):
        """curl -s --header 'Accept: text/html' https://pypi.org/simple/pytest"""
        response = unittest.mock.MagicMock()
        response.geturl.return_value = ""
        response.getcode.return_value = 200
        response.read.return_value = Path("python/private/assets/pytest.html").read_bytes()
        response.__enter__.return_value = response
        mock_urlopen.return_value = response

        index = asyncio.run(parser.get_simple_index("pytest", "https://pypi.org/simple/pytest"))
        assert set(self.expected.items()) & set(index.items())


if __name__ == "__main__":
    unittest.main()
