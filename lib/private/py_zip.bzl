"""
Support for serverless deployments.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":runfiles.bzl", _matches = "matches")

def _py_zip_impl(ctx):
    basename = ctx.label.name
    targets = ctx.attr.target if type(ctx.attr.target) == "list" else [ctx.attr.target]
    deps = [file for target in targets for file in target[DefaultInfo].default_runfiles.files.to_list()]

    output_file = ctx.actions.declare_file(basename + ".zip")

    args, filtered_deps = [], []
    workspace_dir = ctx.label.workspace_name or "_main"

    for dep in deps:
        short_path = paths.normalize(paths.join(workspace_dir, dep.short_path))
        if _matches(short_path, ctx.attr.exclude):
            continue

        args.append(short_path + "=" + dep.path)
        filtered_deps.append(dep)

    python_paths = [workspace_dir] + [path for target in targets for path in target[PyInfo].imports.to_list()]
    json_file = ctx.actions.declare_file(basename + ".json")
    ctx.actions.write(json_file, json.encode({"environment": {"PYTHONPATH": ":".join(python_paths)}}))

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
