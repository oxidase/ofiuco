import argparse
import itertools
import json
import os
import re
import sys
import tomllib
from collections import defaultdict
from dataclasses import dataclass, field
from enum import StrEnum, auto
from operator import attrgetter
from pathlib import Path
from typing import Any

VISIBILITY = """visibility = ["//visibility:public"]"""
SEMVER_REGEXP = re.compile(
    r"^(?P<major>\d+)(?:\.(?P<minor>\d+))?(?:\.(?P<patch>\d+))?(?:\.(?P<rev>\d+))?(?:(?P<pre>[0-9A-Za-z\-.]+))?(?:\+(?P<build>[0-9A-Za-z\-.]+))?$"
)


class SourceType(StrEnum):
    """Ref poetry/packages/locker.py"""

    directory = auto()
    file = auto()
    git = auto()
    hg = auto()
    legacy = auto()
    url = auto()


@dataclass
class Source:
    type: SourceType
    url: str
    reference: str
    resolved_reference: str
    subdirectory: str


@dataclass
class Package:
    name: str
    version: str | None = None
    description: str = ""
    files: list[str, str] = field(default_factory=list)
    markers: str = ""
    dependencies: dict[str, Any] = field(default_factory=dict)
    extras: dict[str, list[str]] = field(default_factory=dict)
    source: Source | None = None
    develop: bool = False

    def __post_init__(self):
        assert self.name
        self.constraint = f"{self.name}=={self.version.split('+')[0]}" if self.version is not None else None

    @property
    def semver(self) -> tuple[int, int, int, int]:
        if self.version is not None and (m := re.match(SEMVER_REGEXP, self.version)) is not None:
            return (int(m["major"]), int(m["minor"] or 0), int(m["patch"] or 0), int(m["rev"] or 0))
        return (0, 0, 0, 0)

    @staticmethod
    def _escape(s):
        return s.replace(r"\"", r"\\\"")

    @staticmethod
    def _normalize(dep_name):
        return dep_name.strip().strip('"').strip("'").replace("_", "-").replace(".", "-").lower()

    @staticmethod
    def from_lock(package: dict[str, Any], project_root: Path):
        source = package.get("source", {})
        dependencies = {Package._normalize(name): attr for name, attr in package.get("dependencies", {}).items()}

        if source.get("type") == SourceType.directory:
            # Resolve relative paths to system local paths (remote cache poisoning alert)
            source["url"] = os.fspath(project_root / source["url"])

        return Package(
            name=package.get("name"),
            version=package.get("version"),
            description=package.get("description", ""),
            dependencies=dependencies,
            markers=package.get("markers", ""),
            files={entry["file"]: entry["hash"] for entry in package.get("files", [])},
            extras=package.get("extras", {}),
            source=package.get("source", {}),
            develop=package.get("develop", False),
        )

    def repr_extras(self):
        return "\n".join(
            f"""
py_library(
  name = "{self.name}[{name}]",
  deps = [{deps}],
  {VISIBILITY},
)
"""
            for name, extra_deps in self.extras.items()
            if (deps := ", ".join([f'":{dep}"' for dep in {self._normalize(dep.split(" ")[0]) for dep in extra_deps}]))
        )

    def repr(self, platforms, generate_extras):
        sep = "\n  "
        attr_sep = "," + sep
        markers = {name: attr["markers"] for name, attr in self.dependencies.items() if "markers" in attr}

        attrs = {
            "constraint": [f'"{self.constraint}"'] if self.constraint else [],
            "description": [f'"""{self.description}"""'] if self.description else [],
            "files": (
                ["{", *(f'  "{name}": "{value}",' for name, value in self.files.items()), "}"] if self.files else []
            ),
            "deps": (
                ["[", *(f'  ":{name}",' for name in sorted(set(self.dependencies))), "]"] if self.dependencies else []
            ),
            "markers": [f'"""{self._escape(json.dumps(markers))}"""'] if markers else [],
            "platforms": (
                ["{", *(f"""  "{name}": '''{value}''',""" for name, value in platforms.items()), "}"]
                if platforms
                else []
            ),
            "source": [f'"""{self._escape(json.dumps(self.source))}"""'] if self.source else [],
            "develop": ["True"] if self.develop else [],
        }

        return f"""
package(
  name = "{self.name}",
  {attr_sep.join((attr + " = " + sep.join(value)) for attr, value in attrs.items() if value)},
  {VISIBILITY},
)
{self.repr_extras() if generate_extras and self.extras else ""}
"""


def remove_cycles(dependency_graph, path, u, removed_edges):
    for v in dependency_graph[u]:
        if v in removed_edges[u]:
            pass
        elif v in path:
            removed_edges[u].add(v)
        else:
            remove_cycles(dependency_graph, path + [u], v, removed_edges)


def parse_poetry_lock(lock_file, platforms, generate_extras, project_root):
    # Collect packages
    with lock_file.open("rb") as lock_handle:
        conf = tomllib.load(lock_handle)
    locked_packages = [Package.from_lock(package, project_root) for package in conf.get("package", [])]

    # Process packages
    packages = []
    name_getter = attrgetter("name")
    for name, group in itertools.groupby(sorted(locked_packages, key=name_getter), key=name_getter):
        if len(named_group := list(group)) == 1:
            packages.extend(named_group)
        else:
            # Update packages names and add to packages list
            for sub_package in named_group:
                sub_package.name = f"{sub_package.name}@{sub_package.version}"
            packages.extend(named_group)

            # Create a meta-package with the original name and dependencies list
            packages.append(
                Package(
                    name=name,
                    dependencies={dep.name: {"markers": dep.markers} for dep in named_group},
                    files={},
                )
            )

    # Find edges which form dependency cycles
    removed_edges = defaultdict(set)
    dependency_graph = {
        package.name: sorted(set(package.dependencies.keys())) for package in sorted(packages, key=name_getter)
    }
    for start in dependency_graph:
        remove_cycles(dependency_graph, [], start, removed_edges)

    # Remove edges
    for package in packages:
        package.dependencies = {
            name: attr for name, attr in package.dependencies.items() if name not in removed_edges[package.name]
        }

    # Print packages
    sys.stdout.write("".join(package.repr(platforms, generate_extras) for package in packages))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Parse lock file and generate packages.")

    parser.add_argument("input_file", type=Path, help="Path to the lock file")
    parser.add_argument("platforms", nargs="?", type=json.loads, help="JSON string with platforms definitions")
    parser.add_argument("--generate_extras", dest="generate_extras", action="store_true")
    parser.add_argument("--nogenerate_extras", dest="generate_extras", action="store_false")
    parser.add_argument("--project_file", type=Path)
    parser.set_defaults(generate_extras=False)

    args = parser.parse_args(argv)

    project_root = args.project_file.resolve().parent if args.project_file else Path()
    parse_poetry_lock(args.input_file, args.platforms, args.generate_extras, project_root)


if __name__ == "__main__":
    main()
