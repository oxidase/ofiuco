"""py_deps aspect and deps requirements rule."""

load("@rules_python//python:defs.bzl", "PyInfo")

PyDepsInfo = provider(
    doc = "Accumulates the transitive set of Python dependency labels seen so far.",
    fields = {
        "labels": "depset of string labels for every Python target found",
    },
)

# Rule kinds treated as "Python targets" even if they don't (for some
# reason) expose PyInfo directly. Extend this list for custom macros/rules
# in your repo (e.g. "py_wheel", "pytype_library", etc).
_PY_RULE_KINDS = [
    "py_library",
    "py_binary",
    "py_test",
    "py_proto_library",
    "py_grpc_library",
]

# Attributes to recurse into. Add more (e.g. "srcs" if you also want to
# catch py_library-generating macros hidden behind filegroups) as needed.
_DEP_ATTRS = ["deps", "runtime_deps", "exports", "data"]

def _is_python_target(target, ctx):
    if PyInfo in target:
        return True
    return ctx.rule.kind in _PY_RULE_KINDS

def _collect_transitive(ctx):
    transitive = []
    for attr_name in _DEP_ATTRS:
        deps = getattr(ctx.rule.attr, attr_name, None)
        if deps == None:
            continue

        # Some attrs are single labels, most are lists.
        if type(deps) == "list":
            dep_list = deps
        else:
            dep_list = [deps]

        for dep in dep_list:
            if type(dep) != "Target":
                continue
            if PyDepsInfo in dep:
                transitive.append(dep[PyDepsInfo].labels)
    return transitive

def _py_deps_aspect_impl(target, ctx):
    transitive = _collect_transitive(ctx)

    direct_labels = []
    if _is_python_target(target, ctx):
        direct_labels.append(str(target.label))

    labels = depset(direct_labels, transitive = transitive)

    report = ctx.actions.declare_file(
        "{}.py_deps.txt".format(target.label.name),
    )
    ctx.actions.write(
        output = report,
        content = "\n".join(sorted(labels.to_list())) + "\n",
    )

    return [
        PyDepsInfo(labels = labels),
        OutputGroupInfo(py_deps_report = depset([report])),
    ]

py_deps_aspect = aspect(
    implementation = _py_deps_aspect_impl,
    attr_aspects = _DEP_ATTRS,
    doc = """
Collects every Python dependency (PyInfo providers or py_* rule kinds)
reachable from a target and writes them to a `<target>.py_deps.txt` report,
exposed via the `py_deps_report` output group.
""",
)

def _py_requires_file_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".txt")

    lines = []
    for dep in ctx.attr.target[PyDepsInfo].labels.to_list():
        if dep.startswith("@@ofiuco"):
            _, name = dep.split(":")

            if name in ctx.attr.requirements:
                lines.append("{}=={}".format(name, ctx.attr.requirements[name]))

    ctx.actions.write(
        output = out,
        content = "\n".join(lines) + "\n",
    )

    return [
        DefaultInfo(files = depset([out])),
    ]

py_requires_file = rule(
    implementation = _py_requires_file_impl,
    attrs = {
        "target": attr.label(
            mandatory = True,
            aspects = [py_deps_aspect],
        ),
        "requirements": attr.string_dict(
            mandatory = True,
            doc = "Map from package name to pinned version.",
        ),
    },
)
