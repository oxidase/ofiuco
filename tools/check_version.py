#!/usr/bin/env python3

import re
import tomllib

with open("pyproject.toml", "rb") as handle:
    conf = tomllib.load(handle)

version = conf["project"]["version"]

with open("README.md", "r+") as handle:
    data = handle.read()
    data = re.sub(r"""bazel_dep\(name = "ofiuco", version = "[^"]+"\)""",  f"""bazel_dep(name = "ofiuco", version = "{version}")""", data)
    handle.seek(0)
    handle.write(data)
