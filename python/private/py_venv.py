import argparse
from pathlib import Path

from python.private.utils import populate_symlink_tree

SKIP_SET = {Path("requirements.txt")}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Create symbolic links in virtual environment to a package")

    parser.add_argument("target", type=Path, help="output virtual environment directory")
    parser.add_argument("path", type=Path, nargs="*", help="python package path")

    args = parser.parse_args(argv)

    for python_path in args.path:
        populate_symlink_tree(python_path, args.target, SKIP_SET)


if __name__ == "__main__":
    main()
