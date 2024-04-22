import argparse
import filecmp
import os
import warnings
from pathlib import Path

SKIP_SET = {Path("requirements.txt")}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Download and install a Poetry package")

    parser.add_argument("target", type=Path, help="output virtual environment directory")
    parser.add_argument("path", type=Path, nargs="*", help="python package path")

    args = parser.parse_args(argv)

    for python_path in args.path:
        if not python_path.exists() or not python_path.is_dir():
            raise RuntimeError(f"Required Python package directory {python_path} does not exist")

        for directory_path, _, file_names in os.walk(python_path):
            in_package_directory = Path(os.path.relpath(directory_path, python_path))
            target_directory = args.target / in_package_directory
            target_directory.mkdir(parents=True, exist_ok=True)
            relative_directory = Path(os.path.relpath(directory_path, target_directory))

            for file_name in file_names:
                if in_package_directory / file_name in SKIP_SET:
                    continue

                symlink_path = target_directory / file_name
                target_path = relative_directory / file_name
                if symlink_path.exists():
                    if not filecmp.cmp(symlink_path, Path(directory_path) / file_name, shallow=False):
                        warnings.warn(
                            f"{symlink_path} already exists and points to {os.path.realpath(symlink_path)}\n"
                            + f"Skip {target_path} which seems to have different contents"
                        )
                    continue

                symlink_path.symlink_to(target_path)


if __name__ == "__main__":
    main()
