import argparse
import json
import logging
import os
import re
import sys
import warnings
from pathlib import Path

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    from pip._internal.commands import create_command
    from pip._internal.locations import USER_CACHE_DIR
    from pip._internal.models.direct_url import DIRECT_URL_METADATA_NAME


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


# Mapping of toolchain compiler and CPU names
# https://github.com/search?q=repo%3Abazelbuild%2Fbazel+%22values+%3D+%7B%5C%22cpu%5C%22%22&type=code
# to Clang architecture values and CMake flags
# https://clang.llvm.org/docs/CrossCompilation.html#target-triple
cc_compiler_cpu_to_cflags = {
    "clang": {
        "darwin_arm64": ["-arch arm64"],
        "darwin_x86_64": ["-arch x86_64"],
        "darwin_arm64e": ["-arch arm64e"],
    }
}

cc_cpu_to_cmake_args = {
    "darwin_arm64": ["-DCMAKE_SYSTEM_NAME=Darwin", "-DCMAKE_SYSTEM_PROCESSOR=arm64"],
    "darwin_x86_64": ["-DCMAKE_SYSTEM_NAME=Darwin", "-DCMAKE_SYSTEM_PROCESSOR=x86_64"],
    "darwin_arm64e": ["-DCMAKE_SYSTEM_NAME=Darwin", "-DCMAKE_SYSTEM_PROCESSOR=arm64e"],
}


def join(flags):
    return " ".join([flag for flag in flags if flag])


def filter_cxx_builtin_include_directories(flags):
    r"""Bazel rules_cc mixes CXX directories into CFLAGS so compiling of GNU11 can fail ¯\_(ツ)_/¯

    In case of CXXFLAGS C++ header must be followed by C headers to prevent:
    <cstddef> tried including <stddef.h> but didn't find libc++'s <stddef.h> header.
    This usually means that your header search paths are not configured properly.
    The header search paths should contain the C++ Standard Library headers before
    any C Standard Library, and you are probably using compiler flags that make that
    not be the case."""
    cxx_include_directory = re.compile(r"^-[iI].*/c\+\+/")
    return [flag for flag in flags if not cxx_include_directory.match(flag)]


def install(args):
    output_path = Path(args.output)

    # Install wheel
    install_command = create_command("install")

    package_files = json.loads(args.files) if args.files else {}
    source = json.loads(args.source) if args.source else {}
    source_type = source.get("type")
    requirements_file = output_path / "requirements.txt"
    with requirements_file.open("wt") as requirements_fileobj:
        pip_arguments, requirements_lines = [], []
        if source_type == "directory":
            url = source.get("url")
            assert url, f"package.source.url is undefined in {args.input} for {source_type} type"
            requirements_lines = (
                [
                    f"--editable={url}",
                ]
                if args.develop
                else [url]
            )
        elif source_type == "git":
            url, reference = source.get("url"), source.get("resolved_reference")
            assert url, f"package.source.url is undefined in {args.input} for {source_type} type"
            assert reference, f"package.source.resolved_reference is undefined in {args.input} for {source_type} type"
            pip_arguments = ["--editable"] if args.develop else []
            requirements_lines = [f"git+{url}@{reference}"]
        elif source_type == "legacy":
            url = source.get("url")
            assert url, f"package.source.url is undefined in {args.input} for {source_type} type"
            pip_arguments = [f"--extra-index-url={url}\n"]
            requirements_lines = [args.input]
        elif source_type == "url":
            url = source.get("url")
            assert url, f"package.source.url is undefined in {args.input} for {source_type} type"
            requirements_lines = [url]
        else:
            requirements_lines = [args.input]

        requirements_lines += [f" --hash={value}" for value in package_files.values()]
        requirements_fileobj.write("\n".join(pip_arguments + ["\\\n".join(requirements_lines)]))

    install_args = [
        "-r",
        os.fspath(requirements_file),
    ]

    try:
        possible_cache = Path(USER_CACHE_DIR)
        use_cache = os.access(possible_cache, os.W_OK)
    except (PermissionError, OSError):
        use_cache = False

    use_cache = False
    install_args.append(f"--cache-dir={possible_cache}" if use_cache else "--no-cache-dir")

    install_args += [
        f"--target={output_path}",
        "--prefer-binary",
        "--no-compile",
        "--no-dependencies",
        "--disable-pip-version-check",
        "--use-pep517",
    ]

    if True:
        install_args += [
            "--quiet",
        ]
    else:
        install_args += [
            # "--no-build-isolation",
            "--no-clean",
        ]

    if args.cc_toolchain is not None:
        cc = json.loads(args.cc_toolchain)
        compiler = cc.get("compiler")
        cpu = cc.get("cpu")

        paths = dict(
            AS="AS",
            CC="CC",
            CXX="CXX",
            LD="LD",
            AR="ar_executable",
            CPP="preprocessor_executable",
            GCOV="gcov_executable",
            NM="nm_executable",
            OBJCOPY="objcopy_executable",
            OBJDUMP="objdump_executable",
            STRIP="strip_executable",
        )

        cpu_flags = cc_compiler_cpu_to_cflags.get(compiler, {}).get(cpu, [])
        asflags = cpu_flags + cc.get("ASFLAGS", [])
        cflags = cpu_flags + filter_cxx_builtin_include_directories(cc.get("CFLAGS", []))
        cxxflags = cpu_flags + cc.get("CXXFLAGS", [])
        ldflags = ["-Wl,-rpath,{}".format(cc.get("dynamic_runtime_solib_dir", ""))] + cc.get("LDFLAGS", [])
        flags = dict(
            ASMFLAGS=join(asflags),
            ASFLAGS=join(asflags),
            CFLAGS=join(cflags),
            CXXFLAGS=join(cxxflags),
            LDFLAGS=join(ldflags),
            CMAKE_ARGS=join(cc_cpu_to_cmake_args.get(cpu, []) + ["-DCMAKE_VERBOSE_MAKEFILE=ON"]),
        )

        os.environ.update(flags)
        os.environ.update({k: os.fspath(Path(cc[v]).resolve()) for k, v in paths.items() if v in cc})

    if retcode := install_command.main(install_args + get_platform_args(args)):
        logging.error(f"pip install returned {retcode}")
        return retcode

    # Propagate *.pth paths as symbolic links as pth files are not loaded dynamically via PYTHONPATH
    if args.develop:
        for pth_file in output_path.glob("*.pth"):
            for directory in [
                path
                for line in pth_file.read_text().split("\n")
                if line
                and not line.startswith("#")
                and not line.startswith("import")
                and (path := (output_path / line).resolve()).is_dir()
            ]:
                for entry in directory.iterdir():
                    symlink_path = output_path / entry.name
                    if not symlink_path.exists():
                        symlink_path.symlink_to(entry)

    # Clean-up some metadata files which may contain non-hermetic data
    for direct_url_path in output_path.glob(f"*.dist-info/{DIRECT_URL_METADATA_NAME}"):
        direct_url_path.unlink()
        record_path = direct_url_path.parent / "RECORD"
        if record_path.exists():
            direct_url_line = f"{direct_url_path.relative_to(output_path)},"
            with open(record_path) as record_file:
                records = record_file.readlines()
            with open(record_path, "w") as record_file:
                record_file.writelines(record for record in records if not record.startswith(direct_url_line))

    if args.entry_points:
        # Ref: https://packaging.python.org/en/latest/specifications/entry-points/#file-format
        args.entry_points.parent.mkdir(parents=True, exist_ok=True)
        entry_points = list(output_path.glob("*.dist-info/entry_points.txt"))
        if entry_points:
            args.entry_points.symlink_to(os.path.relpath(entry_points.pop(), args.entry_points.parent))
            assert not entry_points
        else:
            args.entry_points.touch()

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download and install a Poetry package")
    subparsers = parser.add_subparsers(required=True)

    parser_install = subparsers.add_parser("install")
    parser_install.set_defaults(func=install)
    parser_install.add_argument("input", type=str, help="wheel version constraint")
    parser_install.add_argument("output", type=Path, default=Path(), help="package output directory")
    parser_install.add_argument("--files", type=str, default="{}", help="files:hash  dictionary")
    parser_install.add_argument("--python_version", type=str, default=None, help="python version")
    parser_install.add_argument("--platform", type=str, nargs="*", action="extend", help="platform tag")
    parser_install.add_argument("--source", type=str, help="source JSON ")
    parser_install.add_argument("--develop", action="store_true", help="Install develop package")
    parser_install.add_argument("--cc_toolchain", type=str, help="CC toolchain")
    parser_install.add_argument("--entry_points", type=Path, help="Add a symbolic link to .dist-info/entry_points.txt")

    args = parser.parse_args()
    sys.exit(args.func(args))
