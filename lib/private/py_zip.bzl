"""
Support for serverless deployments.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":runfiles.bzl", _matches = "matches")

DEFAULT_STUB_SHEBANG = "#!/usr/bin/env python3"

def _py_zip_impl(ctx):
    basename = ctx.label.name
    target = ctx.attr.target[0] if type(ctx.attr.target) == "list" else ctx.attr.target
    deps = target[DefaultInfo].default_runfiles.files.to_list()
    workspace_dir = ctx.label.workspace_name or "_main"

    ## Create a package __main__.py entry
    zip_main_entry = ctx.actions.declare_file(basename + "_main_entry.py")
    ctx.actions.expand_template(
        template = ctx.file._python_stub,
        output = zip_main_entry,
        substitutions = {
            "%shebang%": DEFAULT_STUB_SHEBANG,
            # assume the generated app is the first entry in dependencies depset
            "%main%": "{}/{}".format(workspace_dir, deps[0].short_path),
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

    ## Collect runfiles and prepare the arguments list
    args, filtered_deps = ["__main__.py=" + zip_main_entry.path], [zip_main_entry]
    for dep in deps:
        short_path = paths.normalize(paths.join(workspace_dir, dep.short_path))
        if _matches(short_path, ctx.attr.exclude):
            continue

        args.append(short_path + "=" + dep.path)
        filtered_deps.append(dep)

    ## Genrate a JSON files with enviroment variables for downstream consumers
    python_paths = [workspace_dir] + [path for path in target[PyInfo].imports.to_list()]
    json_file = ctx.actions.declare_file(basename + ".json")
    ctx.actions.write(json_file, json.encode({"environment": {"PYTHONPATH": ":".join(python_paths)}}))

    ## Package zip file
    output_file = ctx.actions.declare_file(basename + ".zip")
    ctx.actions.run(
        outputs = [output_file],
        inputs = filtered_deps,
        executable = ctx.executable._zipper,
        arguments = ["cC", output_file.path] + args,
        progress_message = "Creating archive...",
        mnemonic = "archiver",
        env = {
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
        },
    )

    ## Output providers
    out = depset(direct = [output_file, json_file])
    return [
        DefaultInfo(
            files = out,
        ),
        OutputGroupInfo(
            all_files = out,
        ),
    ]

def with_transition(cfg, allowlist = None):
    attrs = {
        "target": attr.label(cfg = cfg),
        "exclude": attr.string_list(),
        "_python_stub": attr.label(
            default = "@bazel_tools//tools/python:python_bootstrap_template.txt",
            allow_single_file = True,
        ),
        "_zipper": attr.label(
            default = Label(":zipper"),
            cfg = "exec",
            executable = True,
        ),
    }
    if type(cfg) == "transition":
        allowlist = allowlist or "@bazel_tools//tools/allowlists/function_transition_allowlist"
        attrs["_allowlist_function_transition"] = attr.label(default = allowlist)

    return rule(
        implementation = _py_zip_impl,
        attrs = attrs,
        executable = False,
        test = False,
    )
