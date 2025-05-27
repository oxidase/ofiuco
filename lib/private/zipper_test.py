import os
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
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
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
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
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
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            file_list = zip_ref.namelist()
            assert file_list == [os.path.basename(__file__)]


    def test_directory(self):
        zip_path = os.path.join(self.tmpdir, "test.zip")
        files = [os.path.dirname(__file__)]

        main(["cf", zip_path] + files)
        assert os.path.exists(zip_path)
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            file_list = [os.path.basename(path) for path in zip_ref.namelist()]
            dir_list = [path for path in os.listdir(os.path.dirname(__file__)) if "__pycache__" not in path]
            assert sorted(file_list) == sorted(dir_list)


    def test_manifest(self):
        manifeft_path = os.path.join(self.tmpdir, "manifest")
        zip_path = os.path.join(self.tmpdir, "test.zip")

        with open(manifeft_path, "wt") as manifest:
            manifest.write(f"test/script={__file__}")

        main(["-m",  manifeft_path, "cC", zip_path])
        assert os.path.exists(zip_path)
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            file_list = zip_ref.namelist()
            assert file_list == ["test/script"]



if __name__ == "__main__":
    unittest.main()
