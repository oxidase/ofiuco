load("@ofiuco//python:repositories.bzl", "install_dependencies")

def _internal_deps_impl(module_ctx):
    install_dependencies("python_3_12", "3.12")

internal_deps = module_extension(
    implementation = _internal_deps_impl,
    tag_classes = {
        "install": tag_class(dict()),
    },
)
