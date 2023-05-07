load("@rules_poetry//python:repositories.bzl", "install_dependencies")
load("@rules_poetry//python:poetry_venv.bzl", "poetry_venv")

def _poetry_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.parse:
            poetry_venv(
                name = attr.name,
                lock = attr.lock,
                platforms = attr.platforms,
            )

poetry = module_extension(
    implementation = _poetry_impl,
    tag_classes = {
        "parse": tag_class(
            attrs = {
                "name": attr.string(mandatory = True),
                "lock": attr.label(mandatory = True),
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
