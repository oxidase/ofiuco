"""Rules for C++ <-> Python bindings."""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc:defs.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_python//python:defs.bzl", "PyInfo")

# @rules_cc//cc/common:cc_helper_internal.bzl
_BINDING_EXTENSIONS_MAP = {
    "so": ".so",
    "dylib": ".so",
    "dll": ".pyd",
    "pyd": ".pyd",
    "wasm": ".so",
}

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
        name = ctx.label.name,
        language = "c++",
        output_type = "dynamic_library",
        user_link_flags = ["-shared", "-Wl,-rpath,$ORIGIN"] + ctx.attr.linkopts,
        link_deps_statically = ctx.attr.linkstatic,
    )

    dynamic_library = linking_outputs.library_to_link.resolved_symlink_dynamic_library or linking_outputs.library_to_link.dynamic_library
    bindings_symlink = ctx.actions.declare_file(ctx.label.name + _BINDING_EXTENSIONS_MAP.get(dynamic_library.extension), sibling = dynamic_library)
    ctx.actions.symlink(output = bindings_symlink, target_file = dynamic_library)

    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        dynamic_library = dynamic_library,
    )

    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset([library_to_link]),
    )

    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )

    # Collect runfiles
    runfiles = ctx.runfiles(transitive_files = depset([dynamic_library, bindings_symlink] + ctx.files.data))
    for dep in ctx.attr.deps:
        runfiles = runfiles.merge(dep[DefaultInfo].data_runfiles)

    for data in ctx.attr.data:
        runfiles = runfiles.merge(data.data_runfiles)
        runfiles = runfiles.merge(data.default_runfiles)

    return [
        DefaultInfo(
            files = depset([dynamic_library, bindings_symlink]),
            runfiles = runfiles,
        ),
        CcInfo(
            compilation_context = compilation_context,
            linking_context = linking_context,
        ),
        PyInfo(
            transitive_sources = depset([dynamic_library, bindings_symlink]),
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
