load("@rules_python//python:defs.bzl", _PyInfo = "PyInfo", _PyRuntimeInfo = "PyRuntimeInfo", "py_binary")
load("@rules_python//python/private:py_executable_info.bzl", _PyExecutableInfo = "PyExecutableInfo")
load("@rules_python//python/private:py_cc_link_params_info.bzl", _PyCcLinkParamsInfo = "PyCcLinkParamsInfo")

def _linux_x86_64_platform_impl(settings, attr):
    return {"//command_line_option:platforms": [":linux_x86_64"]}

linux_x86_64_transition = transition(
    implementation = _linux_x86_64_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _py_binary_cfg_impl(ctx):
    binary = ctx.attr.binary[0]
    runfiles = ctx.runfiles(files = ctx.files.binary)
    runfiles = runfiles.merge(binary.default_runfiles)
    executable = binary[DefaultInfo].files_to_run.executable
    link = ctx.actions.declare_file(ctx.attr.name)

    ctx.actions.symlink(
        output = link,
        target_file = executable,
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = runfiles,
            executable = link,
        ),
        binary[_PyInfo],
        binary[_PyRuntimeInfo],
        binary[_PyExecutableInfo],
        binary[_PyCcLinkParamsInfo],
    ]

def _py_binary_cfg(cfg):
    return rule(
        implementation = _py_binary_cfg_impl,
        attrs = {
            "binary": attr.label(mandatory = True, cfg = cfg),
            "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
        },
    )

py_binary_linux_x86_64 = _py_binary_cfg(linux_x86_64_transition)
