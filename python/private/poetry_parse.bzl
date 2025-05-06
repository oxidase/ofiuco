load("@ofiuco_defs//:defs.bzl", _python_host = "python_host")

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

def normalize_dep_name(dep_name):
    return dep_name.strip().strip('"').strip("'").replace("_", "-").replace(".", "-").lower()

def parse_lock_file(data, platforms = None, generate_extras = True):
    _MARKERS = "markers = "
    _SOURCE_URL = "url = "
    _SOURCE_TYPE = "type = "

    visibility = ["//visibility:public"]

    # Parse toml file
    packages = {}
    for package_lines in data.split("[[package]]"):
        section, name, version, description, files, deps, markers, extras = "package", "", "", "", "", [], {}, {}
        source_type = ""
        for line in package_lines.split("\n"):
            line = line.strip()
            if line == "[package.dependencies]":
                section = "dependencies"
            elif line == "[package.extras]":
                section = "extras"
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
                dep_name = normalize_dep_name(dep_name)
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

            elif generate_extras and section == "extras" and "=" in line:
                extra_name, extras_list = line.split("=", 1)
                extras_list = [
                    normalize_dep_name(dep.strip(' "').split(" ")[0])
                    for dep in extras_list.strip(' []"').split('", "')
                    if dep and dep[0].isalpha()
                ]
                extras[extra_name.strip()] = {x: True for x in [name] + extras_list}.keys()

        if not name:
            continue

        extra_index_urls = [source_url] if source_type == "legacy" else []
        source_urls = [source_url] if source_type == "file" or source_type == "url" else []

        if name in packages:
            version_, description_, files_, deps_, markers_, source_urls_, extra_index_urls_, extras_ = packages[name]
            if version != version_:
                fail("{} package requires two different versions {} and {}".format(name, version_, version))

            files = files_ + files
            deps = {x: True for x in deps_ + deps}.keys()
            markers.update(markers_)
            source_urls = {x: True for x in source_urls_ + source_urls}.keys()
            extra_index_urls = {x: True for x in extra_index_urls_ + extra_index_urls}.keys()
            extras = extras_ | extras

        packages[name] = [version, description, files, deps, markers, source_urls, extra_index_urls, extras]

    # Find dependencies to be excluded to prevent cycles
    exclude_edges = dfs_cycles({name: deps for name, (_, _, _, deps, _, _, _, _) in packages.items()})

    # Generate BUILD file content
    result = ""
    for name, (version, description, files, deps, markers, source_urls, extra_index_urls, extras) in packages.items():
        deps = ['":{}"'.format(u) for u in deps if u not in exclude_edges[name]]
        result += """
package(
  name = "{name}",
  constraint = "{name}=={version}",{description}
  files = {{{files}
   }},{deps}{markers}{source_urls}{extra_index_urls}{platforms}
  visibility = [{visibility}],
)
""".format(
            name = name,
            version = version,
            description = "\n  " + description + "," if description else "",
            files = files,
            deps = "\n  deps = [{}],".format(", ".join(deps)) if deps else "",
            markers = "\n  markers = '''{}''',".format(json.encode(markers)) if markers else "",
            source_urls = "\n  source_urls = [\n{}\n  ],".format("\n".join(["    " + url + "," for url in source_urls])) if source_urls else "",
            extra_index_urls = "\n  extra_index_urls = [{}],".format(", ".join(extra_index_urls)) if extra_index_urls else "",
            platforms = "\n  platforms = {},".format(platforms) if platforms else "",
            visibility = ", ".join(['"{}"'.format(vis) for vis in visibility]),
        )

        for extra_name, extra_deps in extras.items():
            result += """py_library(
  name = "{name}[{extra}]",
  deps = [{deps}],
  visibility = [{visibility}],
)
""".format(
                name = name,
                extra = extra_name,
                deps = ", ".join(['":{}"'.format(dep) for dep in extra_deps]),
                visibility = ", ".join(['"{}"'.format(vis) for vis in visibility]),
            )

    return result

def _poetry_parse_impl(rctx):
    interpreter = rctx.path(rctx.attr._python_host)
    command = "import tomllib; print('{0}', 1); print('ok'); print(tomllib.load(open('{0}', 'rb')))".format(rctx.path(rctx.attr.lock))
    exec_result = rctx.execute([interpreter, "-c", command], quiet = True)
    if exec_result.return_code:
        fail("Parsing {} failed with exit code {}\n{}\n".format(rctx.attr.lock, exec_result.return_code, exec_result.stderr))

    self = str(rctx.path(rctx.attr._self)).split("/external/")[-1]
    header = "# Autogenerated file by _poetry_parse_impl in {}".format(self)
    header += '''\n\nload("@rules_python//python:py_library.bzl", "py_library")'''
    rules_repository = self.split("/", 1)[0]
    rules_repository = ("@@" if "~" in rules_repository else "@") + rules_repository
    rules_repository = rules_repository.split("+")[0]
    prefix = '''{header}\n\nload("{name}//python:poetry_deps.bzl", "package")'''.format(header = header, name = rules_repository)
    lock_file_content = parse_lock_file(rctx.read(rctx.attr.lock), rctx.attr.platforms, rctx.attr.generate_extras)
    rctx.file("BUILD", "{}\n\n{}".format(prefix, lock_file_content))
    rctx.file("WORKSPACE")

poetry_parse = repository_rule(
    attrs = {
        "lock": attr.label(
            allow_single_file = True,
            doc = "Poetry lock file",
        ),
        "generate_extras": attr.bool(
            default = True,
            doc = "Generate packages with extra dependencies",
        ),
        "platforms": attr.string_dict(
            doc = "The mapping of interpter substrings to Python platform tags and environment markers as a JSON string",
        ),
        "_python_host": attr.label(
            allow_single_file = True,
            default = _python_host,
        ),
        "_self": attr.label(
            allow_single_file = True,
            default = ":poetry_parse.bzl",
        ),
    },
    doc = """Process Poetry lock file.""",
    implementation = _poetry_parse_impl,
)
