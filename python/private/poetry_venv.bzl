def parse_lock_file(data):
    _MARKERS = "markers = "
    result = ""
    for package_lines in data.split("[[package]]"):
        section, name, version, description, files, deps, markers = "package", "", "", "", "", [], {}
        for line in package_lines.split("\n"):
            line = line.strip()
            if line == "[package.dependencies]":
                section = "dependencies"
            elif line.startswith("["):
                section = "unlnown"
            elif section == "package" and line.startswith("name = "):
                name = line
            elif section == "package" and line.startswith("version = "):
                version = line
            elif section == "package" and line.startswith("description = "):
                description = line
            elif section == "package" and line.startswith("{file = ") and ", hash = " in line:
                files += "\n    " + line.replace("{file = ", "").replace(", hash = ", ": ").replace("},", ",")
            elif section == "dependencies" and line:
                dep_name, dep_version = line.split("=", 1)
                dep_name = dep_name.strip().replace("_.", "-").lower()
                deps.append('":{}"'.format(dep_name))
                if _MARKERS in dep_version:
                    dep_marker = dep_version[dep_version.find(_MARKERS) + len(_MARKERS):]
                    for index in range(1, len(dep_marker)):
                        if dep_marker[index - 1] != "\\" and dep_marker[index] == '"':
                            markers[dep_name] = dep_marker[1:index]
                            print(markers[dep_name])
                            break

        if name:
            result += """
package(
  {name},
  {version},{description}
  files = {{{files}
  }},{deps}{markers}
  visibility = [\"//visibility:public\"],
)
""".format(
                name = name,
                version = version,
                description = "\n  " + description + "," if description else "",
                files = files,
                deps = "\n  deps = [{}],".format(", ".join(deps)) if deps else "",
                markers = "\n  markers ='''{}'''".format(json.encode(markers)) if markers else "",
            )

    return result

def _poetry_venv_impl(rctx):
    result = rctx.execute([
        "awk",
        "-f",
        rctx.attr._venv,
        rctx.attr.lock,
    ])
    if result.return_code != 0:
        fail("awk failed (status {}): {}".format(result.return_code, result.stderr))

    # lock_lines = rctx.read(rctx.attr.lock).split("\n")
    # print (lock)

    rules_repository = str(rctx.path(rctx.attr._venv)).split("/")[-3]
    rules_repository = ("@@" if "~" in rules_repository else "@") + rules_repository
    prefix = '''load("{name}//python:poetry_deps.bzl", "package")\n'''.format(name = rules_repository)
    rctx.file("BUILD", prefix + result.stdout)
    rctx.file("WORKSPACE")

poetry_venv = repository_rule(
    attrs = {
        "lock": attr.label(
            allow_single_file = True,
            doc = "Poetry lock file",
        ),
        "_venv": attr.label(
            allow_single_file = True,
            default = ":poetry_venv.awk",
        ),
    },
    doc = """Process Poetry lock file.""",
    implementation = _poetry_venv_impl,
)
