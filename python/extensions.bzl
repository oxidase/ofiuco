load("@rules_poetry//python:repositories.bzl", "install_dependencies")
load("@rules_poetry//python:poetry_parse.bzl", "poetry_parse")

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

def _internal_deps_impl(module_ctx):
    install_dependencies()

internal_deps = module_extension(
    implementation = _internal_deps_impl,
    tag_classes = {
        "install": tag_class(dict()),
    },
)
