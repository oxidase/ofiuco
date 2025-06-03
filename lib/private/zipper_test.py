import os
import shutil
import stat
import subprocess
import tempfile
import unittest
import zipfile

from lib.private.zipper import main


class TestZipper(unittest.TestCase):
    tmpdir = os.environ.get("TEST_TMPDIR", tempfile.gettempdir())

    def test_empty_args(self):
        with self.assertRaises(SystemExit):
            main([])

    def test_compress(self):
        zip_path = os.path.join(self.tmpdir, "test.zip")
        files = [__file__]

        main(["cC", zip_path] + files)
        assert os.path.exists(zip_path)
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            file_list = zip_ref.namelist()
            assert file_list == files
            file_info = zip_ref.infolist().pop()
            assert file_info.date_time == (1980, 1, 1, 0, 0, 0)
            assert file_info.compress_type == zipfile.ZIP_DEFLATED

    def test_stored(self):
        zip_path = os.path.join(self.tmpdir, "test.zip")
        files = [os.path.basename(__file__)]

        main(["-d", os.path.dirname(__file__), "c", zip_path] + files)
        assert os.path.exists(zip_path)
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            file_list = zip_ref.namelist()
            assert file_list == files
            file_info = zip_ref.infolist().pop()
            assert file_info.date_time == (1980, 1, 1, 0, 0, 0)
            assert file_info.compress_type == zipfile.ZIP_STORED

    def test_flat(self):
        zip_path = os.path.join(self.tmpdir, "test.zip")
        files = [__file__]

        main(["cf", zip_path] + files)
        assert os.path.exists(zip_path)
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            file_list = zip_ref.namelist()
            assert file_list == [os.path.basename(__file__)]

    def test_directory(self):
        zip_path = os.path.join(self.tmpdir, "test.zip")
        files = [os.path.dirname(__file__)]

        main(["cf", zip_path] + files)
        assert os.path.exists(zip_path)
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            file_list = [os.path.basename(path) for path in zip_ref.namelist()]
            dir_list = [path for path in os.listdir(os.path.dirname(__file__)) if "__pycache__" not in path]
            assert sorted(file_list) == sorted(dir_list)

    def test_manifest(self):
        manifest_path = os.path.join(self.tmpdir, "manifest")
        zip_path = os.path.join(self.tmpdir, "test.zip")

        with open(manifest_path, "w") as manifest:
            manifest.write(f"test/script={__file__}")

        main(["-m", manifest_path, "cC", zip_path])
        assert os.path.exists(zip_path)
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            file_list = zip_ref.namelist()
            assert file_list == ["test/script"]

    def test_shebang(self):
        zip_path = os.path.join(self.tmpdir, "test.zip")
        files = [__file__]

        unzip = shutil.which("unzip")
        shebang = [f"#!{unzip} -l" if unzip else "#!/bin/cat", "# hello"]
        main(["-s", "\n".join(shebang), "cC", zip_path] + files)
        assert os.path.exists(zip_path)
        with open(zip_path, "rb") as zip_file:
            lines = zip_file.readlines()
            assert lines[: len(shebang)] == [line.encode() + b"\n" for line in shebang]
            assert lines[len(shebang)].startswith(b"PK")
            assert os.stat(zip_path).st_mode & stat.S_IXUSR

            result = subprocess.run([zip_path], capture_output=True)
            assert result.returncode == 0
            assert not unzip or b"01-01-1980 00:00" in result.stdout or b"1980-01-01 00:00" in result.stdout
            assert __file__.encode() in result.stdout


if __name__ == "__main__":
    unittest.main()
