import argparse
import asyncio
import html.parser
import itertools
import json
import os
import re
import sys
import tomllib
import urllib
import urllib.parse
import urllib.request
from collections import defaultdict
from dataclasses import dataclass, field
from enum import StrEnum, auto
from operator import attrgetter, itemgetter
from pathlib import Path
from typing import Any

NEW_ISSUE_URL = "https://github.com/oxidase/ofiuco/issues/new"
TODO_MESSAGE = f"TODO: raise new issue at {NEW_ISSUE_URL} for adding support of {{}}"

# Python Versioning
# References:
# [Versioning](https://packaging.python.org/en/latest/discussions/versioning/)
SEMVER_RE = re.compile(
    r"^(?P<major>\d+)"
    r"(?:\.(?P<minor>\d+))?"
    r"(?:\.(?P<patch>\d+))?"
    r"(?:\.(?P<rev>\d+))?"
    r"(?:(?P<pre>[0-9A-Za-z\-.]+))?"
    r"(?:\+(?P<build>[0-9A-Za-z\-.]+))?$"
)

# Binary distribution format file name convention
# References:
# [Binary distribution format](https://packaging.python.org/en/latest/specifications/binary-distribution-format/#file-name-convention)
# [PEP 425 – Compatibility Tags for Built Distributions](https://peps.python.org/pep-0425/)
# [PEP 427 – The Wheel Binary Package Format 1.0](https://peps.python.org/pep-0427/)
WHEEL_RE = re.compile(
    r"^(?P<distribution>[^-]+)"
    r"-(?P<version>[^-]+)"
    r"(?:-(?P<build_tag>[^-]+))?"
    r"-(?P<python_tag>[^-]+)"
    r"-(?P<abi_tag>[^-]+)-"
    r"(?P<platform>.+)?$"
)

WHEEL_PLATFORM_MACOSX_RE = re.compile(r"^macosx_(?P<major>\d+)_(?P<minor>\d+)_(?P<arch>.+)$")
WHEEL_PLATFORM_MUSLLINUX_RE = re.compile(r"^musllinux_(?P<major>\d+)_(?P<minor>\d+)_(?P<arch>.+)$")
WHEEL_PLATFORM_MANYLINUX_RE = re.compile(
    r"^manylinux(?:(?P<legacy>\d+))?(?:_(?P<major>\d+)_(?P<minor>\d+))?_(?P<arch>[^.]+)$"
)
WHEEL_PLATFORM_RE = re.compile(
    r"^(?P<os>(linux|manylinux|musllinux|macosx|ios|win))"
    r"(?P<version>(.+))"
    r"(?P<arch>(aarch(32|64)|arm(64(_32|e)?|v[0-9]l?)?|cortex-r(52|82)|i[36]86|mips64|ppc(32|64([bl]e)?)?|riscv(32|64)|s390x|x86_(32|64)))$"
)

MACOSX_VERSIONS = [
    (10, 9),  # Mavericks
    (10, 10),  # Yosemite
    (10, 11),  # El Capitan
    (10, 12),  # Sierra
    (10, 13),  # High Sierra
    (10, 14),  # Mojave
    (10, 15),  # Catalina
    (11, 0),  # Big Sur
    (12, 0),  # Monterey
    (13, 0),  # Ventura
    (14, 0),  # Sonoma
    (15, 0),  # Sequoia
    (16, 0),  # Tahoe
]


def normalize_basename(name):
    return re.sub(r"[^A-Za-z0-9._-]", "-", urllib.parse.unquote(os.path.basename(name)))


def normalize_target_name(name):
    return name.strip().strip('"').strip("'").replace("_", "-").replace(".", "-").lower()


def get_select_condition(parts):
    if m := WHEEL_PLATFORM_RE.match(parts["platform"]):
        arch2cpu = {"armv7l": "armv7", "i686": "x86_32"}
        cpu = arch2cpu.get(m["arch"], m["arch"])
        match m["os"]:
            case "linux" | "manylinux":
                return "{python_tag}-{abi_tag}-linux-{cpu}-glibc".format(**parts, cpu=cpu)
            case "musllinux":
                return "{python_tag}-{abi_tag}-linux-{cpu}-musl".format(**parts, cpu=cpu)

    return "{python_tag}-{abi_tag}-{platform}".format(**parts)


def get_best_match(wheel_targets, *, glibc, musl):
    # Check for musllinux
    parsed = [
        (WHEEL_PLATFORM_MUSLLINUX_RE.match(platform), target)
        for platforms, target in wheel_targets.items()
        for platform in platforms.split(".")
    ]
    if all(m for m, _ in parsed) and len(set(m["arch"] for m, _ in parsed)) == 1:
        versions = sorted(((int(m["major"]), int(m["minor"])), target) for m, target in parsed)
        filtered = [target for version, target in versions if musl >= version]
        return filtered[-1] if filtered else versions[0][1]

    # Check for manylinux
    parsed = [
        (WHEEL_PLATFORM_MANYLINUX_RE.match(platform), target)
        for platforms, target in wheel_targets.items()
        for platform in platforms.split(".")
    ]
    if all(m for m, _ in parsed) and len(set(m["arch"] for m, _ in parsed)) == 1:

        def get_glibc(d):
            if d["legacy"]:
                return {"2010": (2, 12), "2014": (2, 17)}.get(d["legacy"], (2, 5))
            return (int(d["major"]), int(d["minor"]))

        versions = sorted((get_glibc(m.groupdict()), target) for m, target in parsed)
        filtered = [target for version, target in versions if glibc >= version]
        return filtered[-1] if filtered else versions[0][1]

    raise RuntimeError(TODO_MESSAGE.format(f"{wheel_targets = }"))


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
    url: str | None = None
    reference: str | None = None
    resolved_reference: str | None = None
    subdirectory: str | None = None

    @property
    def is_whl(self):
        return self.type == SourceType.file and self.url.endswith(".whl")

    @staticmethod
    def from_poetry_lock(project_root: Path, **kwargs):
        source = Source(**kwargs)

        if source.type in {SourceType.directory, SourceType.file}:
            source.url = os.fspath((project_root / source.url).resolve())

        return source

    @staticmethod
    def from_uv_lock(project_root: Path, **kwargs):
        if url := kwargs.get("url"):
            return Source(type=SourceType.url, url=url)

        if url := kwargs.get("registry"):
            return Source(type=SourceType.legacy, url=url)

        if url := kwargs.get("git"):
            parsed = urllib.parse.urlparse(url)
            url = urllib.parse.urlunparse(parsed._replace(fragment=""))
            return Source(type=SourceType.git, url=url, resolved_reference=parsed.fragment)

        if url := kwargs.get("editable", kwargs.get("virtual")):
            return Source(type=SourceType.directory, url=os.fspath((project_root / url).resolve()))

        if url := kwargs.get("path"):
            return Source(type=SourceType.file, url=os.fspath((project_root / url).resolve()))

        raise NotImplementedError(f"for {project_root = } and {kwargs = }")


@dataclass
class Package:
    name: str
    version: str | None = None
    description: str = ""
    files: dict[str, str] = field(default_factory=dict)
    urls: dict[str, str] = field(default_factory=dict)
    markers: str = ""
    dependencies: dict[str, Any] = field(default_factory=dict)
    extra_dependencies: list[str] = field(default_factory=list)
    extras: dict[str, list[str]] = field(default_factory=dict)
    source: Source | None = None
    develop: bool = False

    @property
    def semver(self) -> tuple[int, int, int, int]:
        if self.version is not None and (m := re.match(SEMVER_RE, self.version)) is not None:
            return (int(m["major"]), int(m["minor"] or 0), int(m["patch"] or 0), int(m["rev"] or 0))
        return (0, 0, 0, 0)

    @property
    def wheels(self) -> dict[str, str]:
        return {k.removesuffix(".whl"): v for k, v in self.files.items() if k.endswith(".whl")}

    @property
    def sdist(self) -> dict[str, str]:
        return {k.removesuffix(".tar.gz"): v for k, v in self.files.items() if k.endswith(".tar.gz")}

    @property
    def select(self) -> dict[str, str]:
        if self.source and self.source.type not in {SourceType.legacy, SourceType.url}:
            kind = "whl" if self.source.is_whl else "pkg"
            return [f'"@{self.name}//:{kind}"']

        # Collect wheel tags and corresponding targets
        wheels = {}
        condition_getter = itemgetter(0)
        for condition, wheels_group in itertools.groupby(
            sorted(
                (
                    (get_select_condition(m.groupdict()), m.groupdict(), f'"@{wheel}//:whl"')
                    for wheel in self.wheels
                    if (m := re.match(WHEEL_RE, wheel))
                    and (m["python_tag"].startswith("cp") or ("py3" in m["python_tag"].split(".")))
                ),
                key=condition_getter,
            ),
            key=condition_getter,
        ):
            if len(wheels_list := list(wheels_group)) == 1:
                _, parts, wheel_target = wheels_list.pop()
                if m := WHEEL_PLATFORM_MACOSX_RE.match(parts["platform"]):
                    # Add back-compatible select conditions for MacOS platforms
                    minimum_major, minimum_minor, arch = int(m["major"]), int(m["minor"]), m["arch"]
                    for major, minor in MACOSX_VERSIONS:
                        if major > minimum_major or major == minimum_major and minor >= minimum_minor:
                            back_compatible = f"{parts['python_tag']}-{parts['abi_tag']}-macosx_{major}_{minor}_{arch}"
                            wheels[back_compatible] = wheel_target
                else:
                    wheels[condition] = wheel_target
            else:
                wheel_targets = {parts["platform"]: wheel_target for _, parts, wheel_target in wheels_list}
                wheels[condition] = get_best_match(wheel_targets, glibc=(2, 31), musl=(1, 1))

        if any_platform := next((target for condition, target in wheels.items() if condition.endswith("any")), None):
            return [any_platform]

        # Source distribution fallback
        sdist = next(iter(self.sdist), None)
        if not wheels and not sdist:
            raise NotImplementedError(TODO_MESSAGE.format(self))

        # Convert to a Starlark list of selection pairs
        conditions = [
            (f'"@ofiuco//python/platforms:{condition}"', wheel_target) for condition, wheel_target in wheels.items()
        ] + [('"//conditions:default"', f'"@{sdist}//:sdist"' if sdist else None)]

        if len(conditions) == 1:
            return [conditions[0][1]]

        return ["select({", *[f"  {condition}: {target}," for condition, target in conditions], "})"]

    @staticmethod
    def _escape(s):
        return s.replace(r"\"", r"\\\"")

    @staticmethod
    def from_poetry_lock(package: dict[str, Any], project_root: Path):
        dependencies = {
            normalize_target_name(name): values
            for name, attr in package.get("dependencies", {}).items()
            # Don't include optional dependencies
            if (values := attr if isinstance(attr, dict) else {"optional": False}) and not values.get("optional")
        }
        source = (
            Source.from_poetry_lock(project_root, **source_dict) if (source_dict := package.get("source")) else None
        )

        return Package(
            name=package.get("name"),
            version=package.get("version"),
            description=package.get("description", ""),
            dependencies=dependencies,
            markers=package.get("markers", ""),
            files={
                normalize_basename(entry["file"]): entry["hash"].removeprefix("sha256:")
                for entry in package.get("files", [])
                if entry["hash"].startswith("sha256:")
            },
            extras=package.get("extras", {}),
            source=source,
            develop=package.get("develop", False),
        )

    @staticmethod
    def from_uv_lock(package: dict[str, Any], project_root: Path):
        dependencies = {normalize_target_name(attr["name"]): attr for attr in package.get("dependencies", [])}
        source = Source.from_uv_lock(project_root, **source_dict) if (source_dict := package.get("source")) else None
        files = package.get("wheels", []) + ([sdist] if (sdist := package.get("sdist")) else [])
        files = [{"url": source.url} | entry for entry in files]
        urls = {
            entry["hash"].removeprefix("sha256:"): entry["url"]
            for entry in files
            if entry["hash"].startswith("sha256:")
        }

        return Package(
            name=package.get("name"),
            version=package.get("version"),
            dependencies=dependencies,
            source=source,
            urls=urls,
            files={normalize_basename(url): hsh for hsh, url in urls.items()},
        )

    def repr_extras(self):
        return "\n".join(
            f"""
py_library(
  name = "{self.name}[{name}]",
  deps = [":{self.name}", {deps}],
  visibility = ["//visibility:public"],
)
"""
            for name, extra_deps in self.extras.items()
            if (
                deps := ", ".join(
                    [f'":{dep}"' for dep in {normalize_target_name(dep.split(" ")[0]) for dep in extra_deps}]
                )
            )
        )

    def repr(self, platforms, generate_extras):
        sep = "\n  "
        attr_sep = "," + sep
        markers = {
            name: marker
            for name, attr in self.dependencies.items()
            if (marker := attr.get("markers", attr.get("marker")))
        }
        dependencies = [f":{name}" for name in sorted(set(self.dependencies))] + sorted(set(self.extra_dependencies))

        attrs = {
            "description": [f'"""{self.description}"""'] if self.description else [],
            "package": self.select if self.version else [],
            "deps": (["[", *(f'  "{name}",' for name in dependencies), "]"] if dependencies else []),
            "markers": ([f'"""{self._escape(json.dumps(markers))}"""'] if markers else []),
            "platforms": (
                [
                    "{",
                    *(f"""  "{name}": '''{value}''',""" for name, value in platforms.items()),
                    "}",
                ]
                if platforms
                else []
            ),
            "develop": ["True"] if self.develop else [],
            "visibility": ['["//visibility:public"]'],
        }

        return f"""
package(
  name = "{self.name}",
  {attr_sep.join((attr + " = " + sep.join(value)) for attr, value in attrs.items() if value)},
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


def find_unique_name(names, suffix):
    possible_collisions = {name for name in names if name.endswith(suffix)}
    name = suffix
    while name in possible_collisions:
        name = "_" + name
    return name


# Load packages from a Poetry lock file
def load_poetry_locked_packages(lock_file, project_root):
    # Collect packages
    with lock_file.open("rb") as lock_handle:
        conf = tomllib.load(lock_handle)
    return [Package.from_poetry_lock(package, project_root) for package in conf.get("package", [])]


# Load packages from a uv lock file
def load_uv_locked_packages(lock_file, project_root):
    # Collect packages
    with lock_file.open("rb") as lock_handle:
        conf = tomllib.load(lock_handle)
    return [Package.from_uv_lock(package, project_root) for package in conf.get("package", [])]


async def get_simple_index(name, index_url):
    """Legacy (PEP 503) and JSON-based (PEP 691) index parser."""
    package_index_url = f"{index_url}/{name}/"

    async def fetch():
        pypi_simple_mime_type = "application/vnd.pypi.simple.v1+json"
        request = urllib.request.Request(package_index_url, headers={"Accept": pypi_simple_mime_type})
        with urllib.request.urlopen(request) as response:
            if response.getcode() != 200:
                raise RuntimeError(f"Unexpected status code: {response.getcode()} for {package_index_url}")

            if response.headers.get_content_type() == pypi_simple_mime_type:
                return {
                    sha256: url
                    for e in json.loads(response.read()).get("files", [])
                    if (sha256 := e.get("hashes", {}).get("sha256")) is not None and (url := e.get("url")) is not None
                }

            # Fallback to HTML index
            urls = {}

            class LinkParser(html.parser.HTMLParser):
                SHA256_FRAGMENT_RE = re.compile(r"#sha256=([0-9a-fA-F]{64})")

                def handle_starttag(self, tag, attrs):
                    if tag == "a" and (href := dict(attrs).get("href")) and (m := self.SHA256_FRAGMENT_RE.search(href)):
                        urls[m.group(1)] = urllib.parse.urljoin(response.geturl(), href)

            html_data = response.read().decode()
            LinkParser().feed(html_data)
            return urls

    return await fetch()


async def read_package_files(package):
    # Get files from a server with Simple API
    # Ref: https://packaging.python.org/en/latest/specifications/simple-repository-api/#
    index_url = "https://pypi.org/simple"
    build_file = """package(default_visibility = ["//visibility:public"])
filegroup(
    name="{kind}",
    srcs = glob(["**/*"], exclude = ["target/**", "tests/**", "**/__pycache__/**", "*.egg-info/**"]),
)"""

    urls = {}
    if package.source is not None:
        match package.source.type:
            case SourceType.file:
                return [
                    dict(
                        kind="http_archive",
                        name=package.name,
                        url=f"file://{package.source.url}",
                        # TODO: add sha256 if exists in lock file
                        build_file=build_file.format(kind="whl" if package.source.is_whl else "pkg"),
                    )
                ]

            case SourceType.directory:
                return [
                    dict(
                        kind="local_repository",
                        name=package.name,
                        path=package.source.url,
                        build_file=build_file.format(kind="pkg"),
                    )
                ]

            case SourceType.git:
                return [
                    dict(
                        kind="git_repository",
                        name=package.name,
                        remote=package.source.url,
                        commit=package.source.resolved_reference or package.source.reference,
                        build_file=build_file.format(kind="pkg"),
                    )
                ]

            case SourceType.url:
                urls = {package.files[normalize_basename(package.source.url)]: package.source.url}

            case SourceType.legacy:
                index_url = package.source.url

            case _:
                raise NotImplementedError(TODO_MESSAGE.format(package.source))

    # Python packagesindex index
    urls = urls or package.urls or await get_simple_index(package.name, index_url)

    repositories = [
        # Binary wheels
        dict(
            kind="http_archive",
            name=name,
            url=urls[sha256],
            sha256=sha256,
            build_file=build_file.format(kind="whl"),
            type="zip",  # Ref: https://peps.python.org/pep-0427/
        )
        for name, sha256 in package.wheels.items()
    ] + [
        # Source distribution
        dict(
            kind="http_archive",
            name=name,
            url=urls[sha256],
            sha256=sha256,
            strip_prefix=name,
            build_file=build_file.format(kind="sdist"),
        )
        for name, sha256 in package.sdist.items()
    ]

    return repositories


def generate_files(locked_packages):
    async def _inner():
        tasks = [asyncio.create_task(read_package_files(package)) for package in locked_packages]
        results = await asyncio.gather(*tasks)
        return [repo for result in results for repo in result]

    repositories = asyncio.run(_inner())
    return json.dumps(repositories, indent=2)


def generate_packages(locked_packages, platforms, generate_extras, extra_deps):
    # Process packages by first grouping by package names
    packages = []
    name_getter = attrgetter("name")
    for name, group in itertools.groupby(sorted(locked_packages, key=name_getter), key=name_getter):
        if len(named_group := list(group)) == 1:
            # If package name is unique then add package directly to the list
            packages.extend(named_group)
        else:
            # If package name is ambiguous then append to the package name the version and add package to the list
            for sub_package in named_group:
                sub_package.name = f"{sub_package.name}@{sub_package.version}"
            packages.extend(named_group)

            # Create a meta-package with the original name and dependencies list with disambiguated names
            packages.append(
                Package(
                    name=name,
                    dependencies={dep.name: {"markers": dep.markers} for dep in named_group},
                )
            )

    # Find back edges which form dependency cycles
    removed_edges = defaultdict(set)
    dependency_graph = {
        package.name: sorted(set(package.dependencies.keys())) for package in sorted(packages, key=name_getter)
    }
    for start in dependency_graph:
        remove_cycles(dependency_graph, [], start, removed_edges)

    # Remove back edges to break dependency cycles
    for package in packages:
        package.dependencies = {
            name: attr for name, attr in package.dependencies.items() if name not in removed_edges[package.name]
        }

    # Append extra dependencies to packages
    for package in packages:
        if extra_deps and (extra := extra_deps.get(package.name)):
            if isinstance(extra, str):
                package.extra_dependencies.append(extra)
            elif isinstance(extra, list):
                package.extra_dependencies.extend(extra)

        if (type_shadow := f"types-{package.name}") in dependency_graph:
            package.dependencies[type_shadow] = {}

    # Generate synthetic targets
    # :_*all contains all non-versioned packages unconditionally
    all_packages = [package.name for package in packages if "@" not in package.name]
    packages.append(
        Package(
            name=find_unique_name(all_packages, "all"),
            dependencies={package: {} for package in all_packages},
        )
    )

    # Print packages
    return "".join(package.repr(platforms, generate_extras) for package in packages)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Parse lock file and generate packages.")

    parser.add_argument("input_file", type=Path, help="Path to the lock file")
    parser.add_argument("platforms", nargs="?", type=json.loads, help="JSON string with platforms definitions")
    parser.add_argument("--deps", type=json.loads, help="JSON string of extra dependencies")
    parser.add_argument("--generate_extras", dest="generate_extras", action="store_true")
    parser.add_argument("--nogenerate_extras", dest="generate_extras", action="store_false")
    parser.add_argument("--project_file", type=Path)
    parser.add_argument("--output", type=str.lower, choices=["packages", "files"])
    parser.set_defaults(generate_extras=False)

    args = parser.parse_args(argv)

    # Load locked data
    project_root = args.project_file.resolve().parent if args.project_file else Path()
    if args.input_file.name == "poetry.lock":
        locked_packages = load_poetry_locked_packages(args.input_file, project_root)
    elif args.input_file.name == "uv.lock":
        locked_packages = load_uv_locked_packages(args.input_file, project_root)
    else:
        raise RuntimeError(f"unknown input type {args.input_file.name}")

    # Process data
    if args.output == "files":
        output = generate_files(locked_packages)
    else:
        output = generate_packages(locked_packages, args.platforms, args.generate_extras, args.deps)

    # Print output
    sys.stdout.write(output)


if __name__ == "__main__":
    main()
