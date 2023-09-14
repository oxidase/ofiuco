def dfs_cycles(graph):
    # Detect pip dependency cycles u->...->v...->w->v and remove edges w->v
    # Graph DFS with path tracking
    excluded_edges = {u: [] for u in graph}
    for start in graph:
        stack = [[start, [start]]]
        visisted = []

        for _ in graph:
            if stack:
                u, path = stack.pop()
                if u in graph and u not in visisted:
                    visisted.append(u)
                    excluded = excluded_edges[u]
                    for v in graph[u]:
                        if v not in excluded:
                            if v in path:
                                # detected a cycle " + " -> ".join(path) + " -> " + v
                                excluded_edges[u].append(v)
                            else:
                                stack.append([v, path + [v]])
    return excluded_edges

def parse_lock_file(data, platforms = None):
    _MARKERS = "markers = "
    _SOURCE_URL = "url = "
    _SOURCE_TYPE = "type = "

    # Parse toml file
    packages = {}
    for package_lines in data.split("[[package]]"):
        section, name, version, description, files, deps, markers = "package", "", "", "", "", [], {}
        source_type = ""
        for line in package_lines.split("\n"):
            line = line.strip()
            if line == "[package.dependencies]":
                section = "dependencies"
            elif line == "[package.source]":
                section = "source"
            elif line.startswith("["):
                section = "unknown"
            elif section == "package" and line.startswith("name = "):
                name = line.replace("name = ", "").strip('",')
            elif section == "package" and line.startswith("version = "):
                version = line.replace("version = ", "").strip('",').split("+")[0]
            elif section == "package" and line.startswith("description = "):
                description = line
            elif section == "package" and line.startswith("{file = ") and ", hash = " in line:
                files += "\n    " + line.replace("{file = ", "").replace(", hash = ", ": ").replace("},", ",")
            elif section == "dependencies" and line and line[0].isalnum():
                dep_name, dep_version = line.split("=", 1)
                dep_name = dep_name.strip().strip('"').strip("'").replace("_", "-").replace(".", "-").lower()
                deps.append(dep_name)
                if _MARKERS in dep_version:
                    dep_marker = dep_version[dep_version.find(_MARKERS) + len(_MARKERS):]
                    for index in range(1, len(dep_marker)):
                        if dep_marker[index - 1] != "\\" and dep_marker[index] == '"':
                            markers[dep_name] = dep_marker[1:index]
                            break

            elif section == "source" and line.startswith(_SOURCE_TYPE):
                source_type = line[len(_SOURCE_TYPE):].strip('"')
            elif section == "source" and line.startswith(_SOURCE_URL):
                source_url = line[len(_SOURCE_URL):]

        if not name:
            continue

        extra_index_urls = [source_url] if source_type == "legacy" else []
        source_urls = [source_url] if source_type == "file" else []

        if name in packages:
            version_, description_, files_, deps_, markers_, source_urls_, extra_index_urls_ = packages[name]
            if version != version_:
                fail("{} package requires two different versions {} and {}".format(name, version_, version))

            deps = {x: True for x in deps_ + deps}.keys()
            markers.update(markers_)
            source_urls = {x: True for x in source_urls_ + source_urls}.keys()
            extra_index_urls = {x: True for x in extra_index_urls_ + extra_index_urls}.keys()
            packages[name] = [version, description, files_ + files, deps, markers, source_urls, extra_index_urls]
        else:
            packages[name] = [version, description, files, deps, markers, source_urls, extra_index_urls]

    # Find dependencies to be excluded to prevent cycles
    exclude_edges = dfs_cycles({name: deps for name, (_, _, _, deps, _, _, _) in packages.items()})

    # Generate BUILD file content
    result = ""
    for name, (version, description, files, deps, markers, source_urls, extra_index_urls) in packages.items():
        if len(source_urls) >= 2:
            fail("Too many source URLs [{}] in package {}. The installation script must be updated".format(", ".join(source_urls), name))

        deps = ['":{}"'.format(u) for u in deps if u not in exclude_edges[name]]
        result += """
package(
  name = "{name}",
  constraint = "{name}=={version}",{description}
  files = {{{files}
   }},{deps}{markers}{source_url}{extra_index_urls}{platforms}
  visibility = [\"//visibility:public\"],
)
""".format(
            name = name,
            version = version,
            description = "\n  " + description + "," if description else "",
            files = files,
            deps = "\n  deps = [{}],".format(", ".join(deps)) if deps else "",
            markers = "\n  markers = '''{}''',".format(json.encode(markers)) if markers else "",
            source_url = "\n  source_url = {},".format(source_urls[0]) if source_urls else "",
            extra_index_urls = "\n  extra_index_urls = [{}],".format(", ".join(extra_index_urls)),
            platforms = "\n  platforms = {},".format(platforms) if platforms else "",
        )

    return result

def _poetry_venv_impl(rctx):
    rules_repository = str(rctx.path(rctx.attr._self)).split("/")[-4]
    rules_repository = ("@@" if "~" in rules_repository else "@") + rules_repository
    prefix = '''load("{name}//python:poetry_deps.bzl", "package")\n'''.format(name = rules_repository)
    rctx.file("BUILD", prefix + parse_lock_file(rctx.read(rctx.attr.lock), rctx.attr.platforms))
    rctx.file("WORKSPACE")

poetry_venv = repository_rule(
    attrs = {
        "lock": attr.label(
            allow_single_file = True,
            doc = "Poetry lock file",
        ),
        "platforms": attr.string_list_dict(
            doc = "The mapping of interpter substrings to Python platform tags and environment markers as a JSON string",
        ),
        "_self": attr.label(
            allow_single_file = True,
            default = ":poetry_venv.bzl",
        ),
    },
    doc = """Process Poetry lock file.""",
    implementation = _poetry_venv_impl,
)
