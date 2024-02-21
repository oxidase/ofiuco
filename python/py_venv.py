import argparse
from pathlib import Path

SKIP_SET = {Path("requirements.txt")}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download and install a Poetry package")

    parser.add_argument("target", type=Path, help="output virtual environment directory")
    parser.add_argument("path", type=Path, nargs="*", help="python package path")

    args = parser.parse_args()

    for python_path in args.path:
        if not python_path.exists() or not python_path.is_dir():
            raise RuntimeError(f"Required Python package directory {path} does not exist")

        for directory_path, _, file_names in python_path.walk():
            in_package_directory = directory_path.relative_to(python_path)
            target_directory = args.target / in_package_directory
            target_directory.mkdir(parents=True, exist_ok=True)
            relative_directory = directory_path.relative_to(target_directory, walk_up=True)

            for file_name in file_names:
                if in_package_directory / file_name not in SKIP_SET:
                    symlink_path = target_directory / file_name
                    target_path = relative_directory / file_name
                    symlink_path.symlink_to(target_path)
