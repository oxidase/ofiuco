load("@ofiuco//python/private:lock_parser.bzl", "parse_lock")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@ofiuco_defs//:defs.bzl", _python_host = "python_host")
load("@ofiuco//lib:defs.bzl", "lib")


def _parse_impl(mctx):
    for mod in mctx.modules:
        for attr in mod.tags.lock:
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

            # Create external repositories for Python packages
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
                name = file["name"]
                _, build_file = lib.prefix_lookup(attr.build_files, name, file["build_file"])
                if file["kind"] == "http_archive":
                    http_archive(
                        name = name,
                        url = file["url"],
                        sha256 = file.get("sha256"),
                        strip_prefix = file.get("strip_prefix"),
                        type = file.get("type"),
                        build_file_content = build_file,
                    )
                elif file["kind"] == "local_repository":
                    new_local_repository(
                        name=name,
                        path=file["path"],
                        build_file_content=build_file,
                    )
                elif file["kind"] == "git_repository":
                    git_repository(
                        name=name,
                        remote=file["remote"],
                        commit=file["commit"],
                        build_file_content=build_file,
                    )


parse = module_extension(
    implementation = _parse_impl,
    tag_classes = {
        "lock": tag_class(
            attrs = {
                "name": attr.string(mandatory = True),
                "lock": attr.label(mandatory = True),
                "toml": attr.label(),
                "deps": attr.string_list_dict(),
                "generate_extras": attr.bool(default = False),
                "platforms": attr.string_dict(),
                "build_files": attr.string_dict(),
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
