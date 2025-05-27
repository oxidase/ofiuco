import glob
import os
import tempfile
import unittest
import zipfile

from python.private.py_venv import SKIP_SET, main

WHEEL_FILE = "python/private/assets/six-1.16.0-py2.py3-none-any.whl"


class TestInstallSubcommand(unittest.TestCase):
    def test_main(self):
        tmpdir = os.environ.get("TEST_TMPDIR", tempfile.gettempdir())
        target = os.path.join(tmpdir, "venv")
        pkg_paths = [os.path.join(tmpdir, "pkg1"), os.path.join(tmpdir, "pkg2")]

        for path in pkg_paths:
            with zipfile.ZipFile(WHEEL_FILE, "r") as zip_ref:
                zip_ref.extractall(path)

        for index, name in enumerate(pkg_paths):
            with open(os.path.join(name, "duplicated_name"), "wt") as f:
                f.write(str(index))

        test_package = os.path.join(tmpdir, "test_pkg")
        os.makedirs(os.path.join(test_package, "test"))
        for name in list(SKIP_SET) + ["test_file", "test/test_file"]:
            with open(os.path.join(test_package, name), "wt") as f:
                f.write("test")

        with self.assertWarnsRegex(UserWarning, expected_regex="Skip"):
            main([target, test_package] + pkg_paths)

        venv_resolved_files = glob.glob(os.path.join(target, "**"), recursive=True)
        venv_files = [os.path.relpath(name, target) for name in venv_resolved_files]

        assert all(os.path.islink(name) or os.path.isdir(name) for name in venv_resolved_files)
        assert "test_file" in venv_files
        assert "test/test_file" in venv_files
        assert "requirements.txt" not in venv_files


if __name__ == "__main__":
    unittest.main()
