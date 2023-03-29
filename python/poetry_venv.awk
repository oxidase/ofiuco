BEGIN { RS="\\[\\[package\\]\\]"; FS="\n" }
{
    section = "package"
    files = ""
    deps = ""
    markers = ""
    for (i=1; i<=NF; i++) {
        if ($i ~ /^\[/) {
            if ($i == "[package.dependencies]") {
                section = "dependencies"
            } else {
                section = "unknown"
            }
        } else {
            if (section == "package") {
                if ($i ~ /^name[[:space:]]*=[[:space:]]*"[^"]+"/) {
                    name = sprintf("\n  %s,", $i)
                } else if ($i ~ /^version[[:space:]]*=[[:space:]]*"[^"]+"/) {
                    version = sprintf("\n  %s,", $i)
                } else if ($i ~ /^description[[:space:]]*=[[:space:]]*"[^"]+"/) {
                    description = sprintf("\n  %s,", $i)
                } else if ($i ~ /{[[:space:]]*file[[:space:]]*=[[:space:]]*"[^"]+", hash[[:space:]]*=[[:space:]]*"[^"]+"[[:space:]]*}/) {
                    file = $i
                    gsub(/{[[:space:]]*file[[:space:]]*=[[:space:]]*/, "", file)
                    gsub(/, hash[[:space:]]*=[[:space:]]*/, ": ", file)
                    gsub(/[[:space:]]*}.*/, ",\n", file)
                    files = files file
                }
            } else if (section == "dependencies") {
                if ($i ~ /^[^[:space:]]+[[:space:]]*=/) {
                    dep = $i
                    gsub(/[[:space:]]*=.*/, "", dep)
                    gsub(/[-_.]+/, "-", dep)
                    gsub(/"/, "", dep)
                    deps = deps sprintf("\":%s\", ", tolower(dep))

                    marker = $i
                    if (gsub(/.*markers[[:space:]]*=[[:space:]]*"/, "", marker) == 1)
                    {
                        marker = substr(marker, 1, match(marker, /[^\\]"/))
                        gsub(/\\"/, "\\\\\"", marker)
                        marker = sprintf("\"%s\":\"%s\"", dep, marker)
                        (markers == "") ? markers = marker : markers = markers "," marker
                    }
                }
            }
        }
    }

    if (deps != "") {
        deps = sprintf("  deps = [%s],\n", deps)
    }
    if (markers != "") {
        markers = sprintf("  markers = '''{%s}''',\n", markers)
    }

    if (name != "")
    {
        printf "\npackage(%s%s%s\n  files = {\n%s  },\n  visibility = [\"//visibility:public\"],\n%s%s)\n", name, version, description, files, deps, markers
    }
}
