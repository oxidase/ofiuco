import argparse
import hashlib
import json
import logging
import os
import sys
from pathlib import Path

from pip._internal.commands import create_command
from pip._internal.models.direct_url import DIRECT_URL_METADATA_NAME

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download and install a Poetry package")
    parser.add_argument("name", type=str, help="Python package constraint")
    parser.add_argument("version", type=str, help="Python package constraint")
    parser.add_argument("--output", type=Path, default=Path(), help="package output directory")
    parser.add_argument("--python-version", type=str, default=None, help="python version")
    parser.add_argument("--platform", type=Path, default=None, help="platform")
    parser.add_argument("--files", type=str, default="{}", help="files:hash  dictionary")

    args = parser.parse_args()

    output_pkg = args.output

    if (local_package_path := Path(args.version)).is_absolute() and local_package_path.exists():
        for item in local_package_path.iterdir():
            (output_pkg / item.name).symlink_to(item)
        sys.exit(0)

    platform_args = []
    if args.python_version:
        platform_args.append(f"--python-version={args.python_version}")
    if args.platform:
        platform_args.append(f"--platform={args.platform}")

    # Pre-process
    output_whl = output_pkg.parent / (output_pkg.name + "_whl")
    output_whl.mkdir(parents=True, exist_ok=True)

    # Download wheel
    download = create_command("download")

    download_args = [
        f"{args.name}=={args.version}",
        f"--destination-directory={os.fspath(output_whl)}",
        "--no-cache-dir",
        "--no-dependencies",
        # "--only-binary=:all:", # TODO: in some cases CC compiler is needed
        "--disable-pip-version-check",
        "--quiet",
    ]

    if retcode := download.main(download_args + platform_args):
        logging.error(f"pip download returned {retcode}")
        # TODO: proper handling of missing platforms
        sys.exit(0)

    # Check SHA256 sum
    downloaded_file = next((item for item in Path(output_whl).iterdir() if item.is_file()), None)
    package_files = json.loads(args.files)
    expected_hash = package_files[downloaded_file.name]
    sha256_prefix = "sha256:"
    if expected_hash.startswith(sha256_prefix):
        expected_sha256sum = expected_hash.removeprefix(sha256_prefix)
        hasher = hashlib.sha256()
        data_buffer = bytearray(1024 * 1024)
        with open(downloaded_file, "rb") as stream:
            while bytes_read := stream.readinto(data_buffer):
                hasher.update(data_buffer[:bytes_read])

        if hasher.hexdigest() != expected_sha256sum:
            logging.error(
                "downloaded file %s has SHA256 sum %s, but expected %s",
                downloaded_file,
                hasher.hexdigest(),
                expected_sha256sum,
            )
            sys.exit(1)
    else:
        logging.warning("unknown hash %s", expected_hash)

    # Install wheel
    install = create_command("install")
    install_args = [
        os.fspath(downloaded_file),
        f"--target={output_pkg.resolve()}",
        "--no-cache-dir",
        "--no-compile",
        "--no-dependencies",
        "--disable-pip-version-check",
        "--use-pep517",
        "--quiet",
    ]

    if retcode := install.main(install_args + platform_args):
        logging.error(f"pip install returned {retcode}")
        # TODO: proper handling of CC toolchains, split download and install steps

    # Clean-up some metadata files which may contain non-hermetic data
    for direct_url_path in output_pkg.glob(f"*.dist-info/{DIRECT_URL_METADATA_NAME}"):
        direct_url_path.unlink()
        record_path = direct_url_path.parent / "RECORD"
        if record_path.exists():
            direct_url_line = f"{direct_url_path.relative_to(output_pkg)},"
            with open(record_path) as record_file:
                records = record_file.readlines()
            with open(record_path, "wt") as record_file:
                record_file.writelines(record for record in records if not record.startswith(direct_url_line))
