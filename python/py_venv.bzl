load("@rules_python//python:defs.bzl", "PyInfo")
load("//python/private:poetry_deps.bzl", _get_imports = "get_imports", _get_transitive_sources = "get_transitive_sources")

def _py_venv_impl(ctx):
    """
    Rule to link Python package into a virtual environment.

    Arguments:
        ctx: The rule context.

    Attributes:
        deps: label_list The package dependencies list.

    Private attributes:
        _py_venv:

    Returns:
        The providers list or a tuple with a venv package.
    """
    deps = ctx.attr.deps
    output = ctx.actions.declare_directory("venv/{}".format(ctx.label.name))
    transitive_depsets = [_get_transitive_sources(dep) for dep in deps]
    transitive_deps = [item for dep in transitive_depsets for item in dep.to_list()]

    import_depsets = depset(transitive = [_get_imports(dep) for dep in deps])
    import_paths = ["{}/external/{}".format(ctx.bin_dir.path, path) for path in import_depsets.to_list()]

    ctx.actions.run(
        outputs = [output],
        inputs = transitive_deps,
        mnemonic = "CreateVenv",
        progress_message = "Creating venv {}".format(ctx.label.name),
        arguments = [output.path] + import_paths,
        use_default_shell_env = True,
        executable = ctx.executable._py_venv,
    )

    runfiles = [output] + transitive_deps + ctx.files.data
    files = depset([output], transitive = transitive_depsets)
    imports = depset(["_main/" + output.short_path])

    return [
        DefaultInfo(files = files, runfiles = ctx.runfiles(files = runfiles)),
        PyInfo(transitive_sources = files, imports = imports),
    ]

py_venv = rule(
    implementation = _py_venv_impl,
    provides = [PyInfo],
    attrs = {
        "data": attr.label_list(allow_files = True, doc = "The package data list"),
        "deps": attr.label_list(doc = "The package dependencies list"),
        "_py_venv": attr.label(default = "//python/private:py_venv", cfg = "exec", executable = True),
    },
)
