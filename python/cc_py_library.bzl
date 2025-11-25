load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc:defs.bzl", "cc_common")
load("@rules_python//python:defs.bzl", "PyInfo")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc/private/toolchain_config:configure_features.bzl", "configure_features")

def _cc_py_library_impl(ctx):
    """
    Rule to generate a Python bindings module.

    Args:
        ctx rule context

    Required toolchains:
         @bazel_tools//tools/cpp:toolchain_type
    """

    # Get CC toolchain info
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    compilation_contexts = [dep[CcInfo].compilation_context for dep in ctx.attr.deps if CcInfo in dep]
    linking_contexts = [dep[CcInfo].linking_context for dep in ctx.attr.deps if CcInfo in dep and dep[CcInfo].linking_context]
    dynamic_libraries = [
        lib.dynamic_library
        for linking_context in linking_contexts
        for linker_input in linking_context.linker_inputs.to_list()
        for lib in linker_input.libraries
        if lib.dynamic_library
    ]

    compilation_context, outputs = cc_common.compile(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        name = ctx.label.name,
        srcs = ctx.files.srcs,
        public_hdrs = ctx.files.hdrs,
        includes = ctx.attr.includes,
        user_compile_flags = ctx.attr.copts,
        defines = ctx.attr.defines,
        compilation_contexts = compilation_contexts,
    )

    linking_outputs = cc_common.link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = outputs,
        linking_contexts = linking_contexts,
        name = ctx.label.name + ".so",
        language = "c++",
        output_type = "executable",
        user_link_flags = ["-shared", "-Wl,-rpath,$ORIGIN"] + ctx.attr.linkopts,
        link_deps_statically = ctx.attr.linkstatic,
    )

    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        dynamic_library = linking_outputs.executable,
    )

    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset([library_to_link]),
    )

    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )

    # Collect runfiles
    runfiles = ctx.runfiles(transitive_files = depset([linking_outputs.executable] + ctx.files.data))
    for dep in ctx.attr.deps:
        runfiles = runfiles.merge(dep[DefaultInfo].data_runfiles)

    for data in ctx.attr.data:
        runfiles = runfiles.merge(data.data_runfiles)
        runfiles = runfiles.merge(data.default_runfiles)

    return [
        DefaultInfo(
            files = depset([linking_outputs.executable]),
            runfiles = runfiles,
        ),
        CcInfo(
            compilation_context = compilation_context,
            linking_context = linking_context,
        ),
        PyInfo(
            transitive_sources = depset([linking_outputs.executable]),
            uses_shared_libraries = True,
        ),
        OutputGroupInfo(compilation_prerequisites_INTERNAL_ = ctx.files.hdrs + ctx.files.srcs),
    ]


cc_py_library = rule(
    implementation = _cc_py_library_impl,
    attrs = {
        "copts": attr.string_list(
            doc = "List of compiler options.",
        ),
        "data": attr.label_list(
            doc = "The list of runtime data labels or files.",
            allow_files = True,
        ),
        "defines": attr.string_list(
            doc = "Set of defines needed to compile this target. Propagated to dependents transitively.",
        ),
        "includes": attr.string_list(
            doc = "Set of include paths needed to compile this target. Propagated to dependents transitively.",
        ),
        "deps": attr.label_list(
            doc = "The list of other CC libraries to be linked in to the binary target or Python modules that have to be added to runtime.",
        ),
        "hdrs": attr.label_list(
            doc = "List of headers needed for compilation of srcs and may be included by dependent rules transitively.",
            allow_files = [".h", ".hh"],
        ),
        "linkopts": attr.string_list(
            doc = "List of linker options.",
        ),
        "linkstatic": attr.bool(
            doc = "Link the dependency libraries in static mode.",
            default = True,
        ),
        "srcs": attr.label_list(
            doc = "The list of source files to be compiled and private inline headers.",
            allow_files = [".cc", ".cpp", ".inl"],
        ),
    },
    fragments = ["cpp", "py"],
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)
