load("@ofiuco//python:repositories.bzl", "install_dependencies")

def _internal_deps_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.host_toolchain:
            python_host = "@python_{}_host//:python".format(attr.python_version.replace(".", "_"))
            install_dependencies(python_host, attr.python_version)

internal_deps = module_extension(
    implementation = _internal_deps_impl,
    tag_classes = {
        "host_toolchain": tag_class(
            doc = "Python which will be used internally as a host and exec Python",
            attrs = {
                "python_version": attr.string(),
            },
        ),
    },
)
