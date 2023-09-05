import argparse
import json
import logging
import os
import sys
import warnings
from pathlib import Path

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
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

    if args.python_version and args.python_version != "3":
        platform_args.append(f"--python-version={args.python_version}")

    return platform_args


def install(args):
    local_package_path = Path(args.input)
    output_path = Path(args.output)
    if local_package_path.is_absolute() and local_package_path.is_dir():
        # Add symbolic links to the local directory
        for item in local_package_path.iterdir():
            (output_path / item.name).symlink_to(item)
        return 0

    # Install wheel
    install_command = create_command("install")

    if local_package_path.is_file():
        install_args = [
            args.input,
        ]
    else:
        possible_cache = Path(__file__).resolve().parent / "__cache__"
        package_files = json.loads(args.files) if args.files else {}
        requirements_file = output_path / "requirements.txt"
        with requirements_file.open("wt") as requirements_fileobj:
            requirements_lines = [args.input] + [f" --hash={value}" for value in package_files.values()]
            requirements_fileobj.write(" \\\n".join(requirements_lines))

        install_args = [
            "-r",
            os.fspath(requirements_file),
            f"--cache-dir={possible_cache}" if os.access(possible_cache, os.W_OK) else "--no-cache-dir",
        ]

    install_args += [
        f"--target={output_path}",
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
    for direct_url_path in output_path.glob(f"*.dist-info/{DIRECT_URL_METADATA_NAME}"):
        direct_url_path.unlink()
        record_path = direct_url_path.parent / "RECORD"
        if record_path.exists():
            direct_url_line = f"{direct_url_path.relative_to(output_path)},"
            with open(record_path) as record_file:
                records = record_file.readlines()
            with open(record_path, "wt") as record_file:
                record_file.writelines(record for record in records if not record.startswith(direct_url_line))

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download and install a Poetry package")
    subparsers = parser.add_subparsers(required=True)

    parser_install = subparsers.add_parser("install")
    parser_install.set_defaults(func=install)
    parser_install.add_argument("input", type=str, help="wheel file or directory with a single wheel file")
    parser_install.add_argument("output", type=Path, default=Path(), help="package output directory")
    parser_install.add_argument("--files", type=str, default="{}", help="files:hash  dictionary")
    parser_install.add_argument("--python-version", type=str, default=None, help="python version")
    parser_install.add_argument("--platform", type=str, nargs="*", action="extend", help="platform tag")

    args = parser.parse_args()
    sys.exit(args.func(args))
