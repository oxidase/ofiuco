def _darwin_arm64_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":darwin_arm64"]}

def _linux_arm64_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":linux_arm64"]}

def _linux_x86_64_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":linux_x86_64"]}

def _win32_x86_64_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":win32_x86_64"]}

darwin_arm64_transition = transition(
    implementation = _darwin_arm64_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

linux_arm64_transition = transition(
    implementation = _linux_arm64_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

linux_x86_64_transition = transition(
    implementation = _linux_x86_64_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

win32_x86_64_transition = transition(
    implementation = _win32_x86_64_platform_impl,
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

py_binary_darwin_arm64 = _py_binary_cfg(darwin_arm64_transition)
py_binary_linux_arm64 = _py_binary_cfg(linux_arm64_transition)
py_binary_linux_x86_64 = _py_binary_cfg(linux_x86_64_transition)
py_binary_win32_x86_64 = _py_binary_cfg(win32_x86_64_transition)
