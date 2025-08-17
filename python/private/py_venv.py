import argparse
import os
from pathlib import Path

from python.private.utils import populate_symlink_tree

SKIP_SET = {Path("requirements.txt"), Path("WORKSPACE"), Path("WORKSPACE.bazel")}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Create symbolic links in virtual environment to a package")

    parser.add_argument("target", type=Path, help="output virtual environment directory")
    parser.add_argument("path", type=Path, nargs="*", help="python package path")
    parser.add_argument("--prefix", type=Path, default=[Path()], nargs="*", help="directory prefix to check")

    args = parser.parse_args(argv)
    prefixes = {Path(), *args.prefix}

    for python_path in args.path:
        for prefix in prefixes:
            if (path := prefix / python_path).exists():
                populate_symlink_tree(path, args.target, SKIP_SET)
                break
        else:
            raise RuntimeError(f"{python_path} does not exists in {prefixes}, cwd {os.getcwd()}")


if __name__ == "__main__":
    main()
