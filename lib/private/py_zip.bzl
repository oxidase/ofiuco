"""
Support for serverless deployments.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//python/private:poetry_deps.bzl", _get_imports = "get_imports")
load(":runfiles.bzl", _matches = "matches")

DEFAULT_STUB_SHEBANG = "#!/usr/bin/env python3"

def _target_platform_transition_impl(settings, attr):
    return {"//command_line_option:platforms": str(attr.platform)} if attr.platform else {}

_target_platform_transition = transition(
    implementation = _target_platform_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _py_zip_impl(ctx):
    basename = ctx.label.name
    target = ctx.attr.target[0] if type(ctx.attr.target) == "list" else ctx.attr.target
    executable = target[DefaultInfo].files_to_run.executable
    deps = target[DefaultInfo].default_runfiles.files.to_list()
    workspace_dir = ctx.label.workspace_name or "_main"

    ## Collect runfiles and prepare the arguments list
    args, filtered_deps = [], []
    for dep in deps:
        short_path = paths.normalize(paths.join(workspace_dir, dep.short_path))
        if _matches(short_path, ctx.attr.exclude):
            continue

        args.append(short_path + "=" + dep.path)
        filtered_deps.append(dep)

    ## Create a package __main__.py entry
    main_short_path = "__main__.py"
    if executable and not _matches(main_short_path, ctx.attr.exclude):
        zip_main_entry = ctx.actions.declare_file(basename + "_main_entry.py")
        ctx.actions.expand_template(
            template = ctx.file._python_stub,
            output = zip_main_entry,
            substitutions = {
                "%shebang%": DEFAULT_STUB_SHEBANG,
                # assume the generated app is the first entry in dependencies depset
                "%main%": "{}/{}".format(workspace_dir, executable.short_path),
                # use the current interpreter to launch the app
                "PYTHON_BINARY = '%python_binary%'": "PYTHON_BINARY = sys.executable",
                "%coverage_tool%": "",
                "%imports%": "",
                "%workspace_name%": workspace_dir,
                "%is_zipfile%": "True",
                "%import_all%": "True",
                # runfiles packeged by zipper without 'runfiles' directory prefix
                "(temp_dir, 'runfiles')": "(temp_dir)",
                # don't use RUNFILES_DIR in directory detection but use module_space as IsRunningFromZip is true
                "return ('RUNFILES_DIR', runfiles)": "pass",
            },
            is_executable = True,
        )
        args.append(main_short_path + "=" + zip_main_entry.path)
        filtered_deps.append(zip_main_entry)

    ## Generate zip manifest file
    manifest_file = ctx.actions.declare_file(basename + ".manifest")
    ctx.actions.write(manifest_file, "\n".join(args))

    ## Genrate a JSON files with enviroment variables for downstream consumers
    python_paths = [workspace_dir] + _get_imports(target).to_list()
    json_file = ctx.actions.declare_file(basename + ".json")
    ctx.actions.write(json_file, json.encode({"environment": {"PYTHONPATH": ":".join(python_paths)}}))

    ## Package zip file
    output_file = ctx.actions.declare_file(basename)
    zipper_args = ["cC", output_file.path, "-m", manifest_file.path]
    zipper_args += ["-s", ctx.attr.shebang] if ctx.attr.shebang else []
    ctx.actions.run(
        outputs = [output_file],
        inputs = [manifest_file] + filtered_deps,
        executable = ctx.executable._zipper,
        arguments = zipper_args,
        progress_message = "Creating archive {}".format(output_file.short_path),
        mnemonic = "archiver",
        env = {
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
        },
    )

    ## Output providers
    return [
        DefaultInfo(
            files = depset(direct = [output_file]),
        ),
        OutputGroupInfo(
            all = [output_file, json_file],
            json = [json_file],
        ),
    ]

py_zip = rule(
    implementation = _py_zip_impl,
    attrs = {
        "target": attr.label(cfg = _target_platform_transition),
        "exclude": attr.string_list(),
        "platform": attr.label(),
        "shebang": attr.string(),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "_python_stub": attr.label(
            default = "@bazel_tools//tools/python:python_bootstrap_template.txt",
            allow_single_file = True,
        ),
        "_zipper": attr.label(
            default = Label(":zipper"),
            cfg = "exec",
            executable = True,
        ),
    },
    executable = False,
    test = False,
)
