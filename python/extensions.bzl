load("@ofiuco//python:poetry_parse.bzl", "poetry_parse")

def _poetry_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.parse:
            poetry_parse(
                name = attr.name,
                lock = attr.lock,
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
                "generate_extras": attr.bool(default = True),
                "platforms": attr.string_dict(),
            },
        ),
    },
)
