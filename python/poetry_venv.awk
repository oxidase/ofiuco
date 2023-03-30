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
                if ($i ~ /^name[ \t]*=[ \t]*"[^"]+"/) {
                    name = sprintf("\n  %s,", $i)
                } else if ($i ~ /^version[ \t]*=[ \t]*"[^"]+"/) {
                    version = sprintf("\n  %s,", $i)
                } else if ($i ~ /^description[ \t]*=[ \t]*"[^"]+"/) {
                    description = sprintf("\n  %s,", $i)
                } else if ($i ~ /{[ \t]*file[ \t]*=[ \t]*"[^"]+", hash[ \t]*=[ \t]*"[^"]+"[ \t]*}/) {
                    file = $i
                    gsub(/{[ \t]*file[ \t]*=[ \t]*/, "", file)
                    gsub(/, hash[ \t]*=[ \t]*/, ": ", file)
                    gsub(/[ \t]*}.*/, ",\n", file)
                    files = files file
                }
            } else if (section == "dependencies") {
                if ($i ~ /^[^ \t]+[ \t]*=/) {
                    dep = $i
                    gsub(/[ \t]*=.*/, "", dep)
                    gsub(/[-_.]+/, "-", dep)
                    gsub(/"/, "", dep)
                    deps = deps sprintf("\":%s\", ", tolower(dep))

                    marker = $i
                    if (gsub(/.*markers[ \t]*=[ \t]*"/, "", marker) == 1)
                    {
                        marker = substr(marker, 1, match(marker, /[^\\]"/))
                        gsub(/\\"/, "\\\\\\\"", marker)
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
