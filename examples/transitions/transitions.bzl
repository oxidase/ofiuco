def _arm64_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":arm64"]}

def _win_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":win"]}

def _x86_64_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":x86_64"]}

arm64_transition = transition(
    implementation = _arm64_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

win_transition = transition(
    implementation = _win_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

x86_64_transition = transition(
    implementation = _x86_64_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _py_binary_cfg_impl(ctx):
    binary = ctx.attr.binary[0]
    runfiles = ctx.runfiles(files = ctx.files.binary)
    runfiles = runfiles.merge(binary.default_runfiles)
    return [
        DefaultInfo(
            runfiles = runfiles,
        ),
        binary[PyInfo],
    ]

def _py_binary_cfg(cfg):
    return rule(
        implementation = _py_binary_cfg_impl,
        attrs = {
            "binary": attr.label(mandatory = True, cfg = cfg),
            "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
        },
    )

py_binary_x86_64 = _py_binary_cfg(x86_64_transition)
py_binary_arm64 = _py_binary_cfg(arm64_transition)
py_binary_win = _py_binary_cfg(win_transition)
