load("//lib/private:globstar.bzl", _globstar = "globstar")

def matches(text, patterns, path_separator = "/"):
    for pattern in patterns:
        if pattern == "**" or _globstar(pattern, text, path_separator):
            return True

    return False

def _runfiles_impl(ctx):
    runfiles = [
        file
        for dep in ctx.attr.data
        for file in dep[DefaultInfo].default_runfiles.files.to_list()
        if matches(file.owner.workspace_name, ctx.attr.workspace, None) and matches(file.path, ctx.attr.include) and not matches(file.path, ctx.attr.exclude)
    ]

    return [
        DefaultInfo(
            files = depset(runfiles),
        ),
    ]

runfiles = rule(
    implementation = _runfiles_impl,
    attrs = {
        "data": attr.label_list(),
        "workspace": attr.string_list(default = ["**"]),
        "include": attr.string_list(default = ["**"]),
        "exclude": attr.string_list(default = []),
    },
    executable = False,
)
