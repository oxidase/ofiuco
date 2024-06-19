import filecmp
import os
import warnings
from pathlib import Path


def populate_symlink_tree(source, target, skip_set=None):
    if not source.exists() or not source.is_dir():
        raise RuntimeError(f"Required Python package directory {source} does not exist")

    for directory_path, _, file_names in os.walk(source):
        in_package_directory = Path(os.path.relpath(directory_path, source))
        target_directory = target / in_package_directory
        target_directory.mkdir(parents=True, exist_ok=True)
        if source.is_absolute():
            relative_directory = Path(directory_path)
        else:
            relative_directory = Path(os.path.relpath(directory_path, target_directory))

        for file_name in file_names:
            if skip_set and in_package_directory / file_name in skip_set:
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
