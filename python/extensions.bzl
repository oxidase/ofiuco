load("@ofiuco//python:lock_parser.bzl", "parse_lock")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")
load("@ofiuco_defs//:defs.bzl", _python_host = "python_host")


def _poetry_impl(mctx):
    for mod in mctx.modules:
        for attr in mod.tags.parse:
            # Files watchers
            mctx.watch(attr.lock)
            if attr.toml:
                mctx.watch(attr.toml)

            # Create repository with packages
            parse_lock(
                name = attr.name,
                lock = attr.lock,
                toml = attr.toml,
                deps = attr.deps,
                generate_extras = attr.generate_extras,
                platforms = attr.platforms,
            )

            # Create external repositories for Pyhton packages
            interpreter = mctx.path(attr._python_host)
            result = mctx.execute([
                interpreter,
                mctx.path(attr._lock_parser),
                mctx.path(attr.lock),
                "--output=files",
            ] + (["--project_file={}".format(mctx.path(attr.toml))] if attr.toml else []))

            if result.return_code != 0:
                fail(result.stderr)


            for file in json.decode(result.stdout):
                if file["kind"] == "http_archive" or file["kind"] == "http_whl_package":
                    http_archive(
                        name = file["name"],
                        url = file["url"],
                        sha256 = file.get("sha256"),
                        strip_prefix = file.get("strip_prefix"),
                        build_file_content = file["build_file"],
                        # Ref: https://peps.python.org/pep-0427/
                        type = "zip" if file["kind"] == "http_whl_package" else "",
                    )
                elif file["kind"] == "new_local_repository":
                    new_local_repository(
                        name=file["name"],
                        path=file["path"],
                        build_file_content=file["build_file"],
                    )
                elif file["kind"] == "new_git_repository":
                    new_git_repository(
                        name=file["name"],
                        remote=file["remote"],
                        commit=file["commit"],
                        build_file_content=file["build_file"],
                    )


poetry = module_extension(
    implementation = _poetry_impl,
    tag_classes = {
        "parse": tag_class(
            attrs = {
                "name": attr.string(mandatory = True),
                "lock": attr.label(mandatory = True),
                "toml": attr.label(),
                "deps": attr.string_list_dict(),
                "generate_extras": attr.bool(default = False),
                "platforms": attr.string_dict(),
                "_lock_parser": attr.label(
                    allow_single_file = True,
                    default = "//python/private:lock_parser.py",
                ),
                "_python_host": attr.label(
                    allow_single_file = True,
                    default = _python_host,
                ),
                "_self": attr.label(
                    allow_single_file = True,
                    default = ":extensions.bzl",
                ),
            },
        ),
    },
)
