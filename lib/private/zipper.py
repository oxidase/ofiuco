import argparse
import logging
import stat
import sys
import zipfile
from pathlib import Path
from typing import List


def get_external_attr(path: Path) -> int:
    """Get zip file external attributes for a path."""
    st = path.stat()
    return (stat.S_IRUSR | stat.S_IWUSR | (st.st_mode & stat.S_IXUSR)) << 16


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
                    file_data = Path(globbed_file).read_bytes()
                    file_info = zipfile.ZipInfo(relative_path)
                    file_info.external_attr = get_external_attr(globbed_file)
                    zipf.writestr(file_info, file_data, compression)
            else:
                zip_path = Path(zip_path).name if flatten else zip_path
                file_data = Path(mayby_file_path).read_bytes() if file_path else b""
                file_info = zipfile.ZipInfo(zip_path)
                file_info.external_attr = get_external_attr(mayby_file_path)
                zipf.writestr(file_info, file_data, compression)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Create a zip file.")
    parser.add_argument("command", type=str, help="command 'vxc[fC]'")
    parser.add_argument("zip", type=str, help="zip file name'")
    parser.add_argument("-d", "--dir", default=".", help="input directory")
    parser.add_argument("-m", dest="manifest", type=Path, help="manifest file")
    parser.add_argument("files", type=str, nargs="*")

    args = parser.parse_args(argv)

    files = args.files
    if args.manifest is not None:
        manifest_lines = [line for line in args.manifest.read_text().split("\n") if line]
        files.extend(manifest_lines)

    if args.command.startswith("c"):
        compress(args.command, Path(args.dir), args.zip, args.files)
    else:
        logging.error("command %s is not supported", args.command)
        sys.exit(1)


if __name__ == "__main__":
    main()
