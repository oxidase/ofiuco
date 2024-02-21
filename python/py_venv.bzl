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
    import_paths = ["{}/external/{}".format(ctx.bin_dir.path, path) for dep in deps for path in dep[PyInfo].imports.to_list()]

    ctx.actions.run(
        outputs = [output],
        inputs = ctx.files.deps,
        mnemonic = "CreateVenv",
        progress_message = "Creating venv {}".format(ctx.label.name),
        arguments = [output.path] + import_paths,
        use_default_shell_env = True,
        executable = ctx.executable._py_venv,
    )

    transitive_depsets = [dep[PyInfo].transitive_sources for dep in deps]
    runfiles = [output] + [item for dep in transitive_depsets for item in dep.to_list()]
    files = depset([output], transitive = transitive_depsets)

    return [
        DefaultInfo(files = files, runfiles = ctx.runfiles(files = runfiles)),
        PyInfo(transitive_sources = files, imports = depset(["_main/" + output.short_path])),
    ]

py_venv = rule(
    implementation = _py_venv_impl,
    provides = [PyInfo],
    attrs = {
        "deps": attr.label_list(doc = "The package dependencies list"),
        "_py_venv": attr.label(default = ":py_venv", cfg = "exec", executable = True),
    },
)
