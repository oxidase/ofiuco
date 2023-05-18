import argparse
import logging
import sys
import zipfile
from pathlib import Path
from typing import List


def compress(options: str, dir_path: Path, output_path: Path, file_paths: List[str]) -> None:
    """Create a zip archive.

    Args:
        options: create options string.
        dir_path: directory path that will be appended to file paths.
        output_path: output archive path.
        file_paths: file path pairs in [zip_path=]file_path format.
    """

    compression = zipfile.ZIP_DEFLATED if "C" in options else zipfile.ZIP_STORED
    flatten = "f" in options

    with zipfile.ZipFile(output_path, "w", compression) as zipf:
        for maybe_paths_pair in sorted(file_paths):
            if maybe_paths_pair.count("=") == 1:
                zip_path, file_path = maybe_paths_pair.split("=")
            else:
                zip_path, file_path = maybe_paths_pair, maybe_paths_pair

            mayby_file_path = dir_path / file_path
            if mayby_file_path.is_dir():
                sorted_files_list = sorted(
                    globbed_file
                    for globbed_file in mayby_file_path.glob("**/*")
                    if not globbed_file.is_dir() and "__pycache__" not in str(globbed_file)
                )
                for globbed_file in sorted_files_list:
                    relative_path = zip_path + str(globbed_file).removeprefix(str(mayby_file_path))
                    file_data = open(globbed_file, "rb").read()
                    file_info = zipfile.ZipInfo(relative_path)
                    zipf.writestr(file_info, file_data, compression)
            else:
                zip_path = Path(zip_path).name if flatten else zip_path
                file_data = open(mayby_file_path, "rb").read() if file_path else b""
                file_info = zipfile.ZipInfo(zip_path)
                zipf.writestr(file_info, file_data, compression)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create a zip file.")
    parser.add_argument("command", type=str, help="command 'vxc[fC]'")
    parser.add_argument("zip", type=str, help="zip file name'")
    parser.add_argument("-d", dest="dir", default=".", help="output directory")
    parser.add_argument("files", type=str, nargs="+")

    args = parser.parse_args()

    if args.command.startswith("c"):
        compress(args.command, Path(args.dir), args.zip, args.files)
    else:
        logging.error("command %s is not supported", args.command)
        sys.exit(1)
