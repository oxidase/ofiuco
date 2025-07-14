load("@ofiuco//python:lock_parser.bzl", "parse_lock")

def _poetry_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.parse:
            parse_lock(
                name = attr.name,
                lock = attr.lock,
                toml = attr.toml,
                deps = attr.deps,
                generate_extras = attr.generate_extras,
                platforms = attr.platforms,
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
                "generate_extras": attr.bool(default = True),
                "platforms": attr.string_dict(),
            },
        ),
    },
)
