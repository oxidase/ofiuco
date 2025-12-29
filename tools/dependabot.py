#!/usr/bin/env python3

# Run as: uv run tools/dependabot.py . (find examples -type d -mindepth 1 -maxdepth 1)

import argparse
import asyncio
import re
import subprocess
import sys
from pathlib import Path

import aiohttp

ROOT_CHILD_RE = re.compile(r"^[├└]───(?P<name>[a-zA-Z0-9_\-\.]+)@(?P<version>[^\s]+)")
REGISTRY_BASE = "https://registry.bazel.build/modules"


async def get_root_children(root: Path) -> dict[str, str]:
    """
    Run `bazel mod graph` and return:
        { module_name: version }
    for direct root children only.
    """
    proc = await asyncio.create_subprocess_shell(
        "bazel mod graph",
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=False,
    )

    stdout, stderr = await proc.communicate()

    return {m["name"]: m["version"] for line in stdout.splitlines() if (m := ROOT_CHILD_RE.match(line.decode()))}


def semver_key(v: str):
    """Robust semver-ish sort"""
    parts = re.split(r"[.\-]", v)
    key = [int(p) if p.isdigit() else p for p in parts]
    if rc := next((i for i, p in enumerate(parts) if isinstance(p, str) and p.startswith("rc")), None):
        borrow = -1
        for i in range(rc - 1, -1, -1):
            key[i], borrow = (key[i] + borrow, 0) if key[i] + borrow >= 0 else (key[i] + 10 + borrow, -1)

    return key


assert semver_key("0.9.9") < semver_key("1.0.0-rc1")
assert semver_key("1.0.0") < semver_key("1.0.0.bcr.1")
assert semver_key("1.0.0-rc1") < semver_key("1.0.0")
assert semver_key("1.0.0-rc1") < semver_key("1.0.0-rc2")


async def fetch_latest_version(session: aiohttp.ClientSession, module: str) -> str | None:
    url = f"{REGISTRY_BASE}/{module}"

    async with session.get(url) as resp:
        if resp.status != 200:
            return None

        html = await resp.text()

    versions = re.compile(rf"/modules/{module}/([0-9][^\"/]+)").findall(html)
    if not versions:
        return None

    # Bazel module versions are semver-compatible strings
    return sorted(versions, key=semver_key)[-1]


async def main(root: str) -> None:
    deps = await get_root_children(root)

    timeout = aiohttp.ClientTimeout(total=30)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        tasks = {name: asyncio.create_task(fetch_latest_version(session, name)) for name in deps}

        output = [f"\nRoot {root} module version check:"]
        for name, task in tasks.items():
            latest = await task
            current = deps[name]
            match (current, latest):
                case "_", _:
                    status = "☘️ skipped"
                case current, None:
                    status = "❓ lookup failed"
                case current, latest if current == latest:
                    status = "✅ up-to-date"
                case current, latest:
                    status = f"⬆️ latest = {latest}"
            output.append(f"{name:20} current = {current:10} {status}")

        sys.stdout.write("\n".join(output))
        sys.stdout.flush()


async def runner(roots: list[Path]):
    await asyncio.gather(*(main(r) for r in roots))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="*", type=Path, default=[Path()], help="Root directories (one or more paths)")
    args = parser.parse_args()

    asyncio.run(runner(args.root))
