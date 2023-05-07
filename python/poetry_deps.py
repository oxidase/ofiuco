import argparse
import hashlib
import json
import logging
import os
import sys
from pathlib import Path

from pip._internal.commands import create_command
from pip._internal.models.direct_url import DIRECT_URL_METADATA_NAME

_SHA256_PREFIX = "sha256:"


def get_platform_args(args):
    """Format Python platform tags and version arguments.

    Ref: https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#platform-tag
    """

    platform_args = []

    if args.platform:
        platform_args = [f"--platform={platform}" for platform in args.platform]

    if args.python_version:
        platform_args.append(f"--python-version={args.python_version}")

    return platform_args


def download(args):
    if args.source_url is not None:
        return 0

    # Download wheel
    download_command = create_command("download")

    download_args = [
        args.constraint,
        f"--destination-directory={os.fspath(args.output)}",
        "--no-cache-dir",
        "--no-dependencies",
        "--prefer-binary",
        "--disable-pip-version-check",
        "--quiet",
    ] + get_platform_args(args)

    if (retcode := download_command.main(download_args)) != 0:
        return retcode

    # Check number of downloaded files and SHA256 sum
    downloaded_files = [item for item in Path(args.output).iterdir() if item.is_file()]
    if len(downloaded_files) != 1:
        raise RuntimeError(f"downloaded {len(downloaded_files)} files but one is expected")

    downloaded_file = downloaded_files.pop()
    package_files = json.loads(args.files)
    expected_hash = package_files[downloaded_file.name]
    if expected_hash.startswith(_SHA256_PREFIX):
        expected_sha256sum = expected_hash.removeprefix(_SHA256_PREFIX)
        hasher = hashlib.sha256()
        data_buffer = bytearray(1024 * 1024)
        with open(downloaded_file, "rb") as stream:
            while bytes_read := stream.readinto(data_buffer):
                hasher.update(data_buffer[:bytes_read])

        if hasher.hexdigest() != expected_sha256sum:
            raise RuntimeError(
                f"downloaded file {downloaded_file} has SHA256 sum {hasher.hexdigest()} "
                + f"but expected {expected_sha256sum}"
            )

    else:
        logging.warning("unknown hash type %s", expected_hash)

    return 0


def install(args):
    if args.kind == "url" and (local_package_path := Path(args.input)).is_absolute() and local_package_path.exists():
        for item in local_package_path.iterdir():
            (args.output / item.name).symlink_to(item)
    else:
        # Install wheel
        install_command = create_command("install")
        install_args = [
            args.input
            if args.kind == "url" or Path(args.input).is_file()
            else os.fspath(next((item for item in Path(args.input).iterdir() if item.is_file()))),
            f"--target={args.output}",
            "--no-cache-dir",
            "--no-compile",
            "--no-dependencies",
            "--disable-pip-version-check",
            "--use-pep517",
            "--quiet",
        ]

        if retcode := install_command.main(install_args + get_platform_args(args)):
            logging.error(f"pip install returned {retcode}")
            # TODO: proper handling of CC toolchains
            return retcode

    # Clean-up some metadata files which may contain non-hermetic data
    for direct_url_path in args.output.glob(f"*.dist-info/{DIRECT_URL_METADATA_NAME}"):
        direct_url_path.unlink()
        record_path = direct_url_path.parent / "RECORD"
        if record_path.exists():
            direct_url_line = f"{direct_url_path.relative_to(args.output)},"
            with open(record_path) as record_file:
                records = record_file.readlines()
            with open(record_path, "wt") as record_file:
                record_file.writelines(record for record in records if not record.startswith(direct_url_line))

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download and install a Poetry package")
    subparsers = parser.add_subparsers(required=True)

    parser_download = subparsers.add_parser("download")
    parser_download.set_defaults(func=download)
    parser_download.add_argument("constraint", type=str, help="Python package constraint")
    parser_download.add_argument("--output", type=Path, default=Path(), help="package output directory")
    parser_download.add_argument("--python-version", type=str, default=None, help="python version")
    parser_download.add_argument("--platform", type=str, nargs="*", action="extend", help="platform tag")
    parser_download.add_argument("--files", type=str, default="{}", help="files:hash  dictionary")
    parser_download.add_argument("--source-url", type=Path, default=None, help="source file URL")

    parser_install = subparsers.add_parser("install")
    parser_install.set_defaults(func=install)
    parser_install.add_argument("kind", type=str, help="installation kind 'wheel' or 'url'")
    parser_install.add_argument("input", type=str, help="wheel file or directory with a single wheel file")
    parser_install.add_argument("output", type=Path, default=Path(), help="package output directory")
    parser_install.add_argument("--python-version", type=str, default=None, help="python version")
    parser_install.add_argument("--platform", type=str, nargs="*", action="extend", help="platform tag")

    args = parser.parse_args()
    sys.exit(args.func(args))
