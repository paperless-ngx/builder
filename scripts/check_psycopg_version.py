#!/usr/bin/env python3
"""Detect whether a newer stable psycopg release is available on PyPI.

Compares the latest stable, non-yanked psycopg version on PyPI against the
highest version this repo has already built (derived from ``psycopg-*`` git
tags). Prints a human-readable summary, and when running inside GitHub Actions
also writes ``current``/``latest``/``should_update`` to ``$GITHUB_OUTPUT``.

Run locally with no arguments to see what the scheduled workflow would decide:

    python3 scripts/check_psycopg_version.py
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import urllib.request

PYPI_URL = "https://pypi.org/pypi/psycopg/json"

# A pure numeric dotted version. Requiring this shape also excludes
# pre-releases and dev releases (e.g. 3.4.0b1, 3.4.0.dev1).
NUM_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)*$")
# New tags are psycopg-<suite>-<version>; legacy tags are psycopg-<version>.
TAG_RE = re.compile(r"^psycopg-(?:[a-z]+-)?([0-9][0-9.]*)$")


def parse(text: str) -> tuple[int, ...]:
    return tuple(int(part) for part in text.split("."))


def fmt(parts: tuple[int, ...]) -> str:
    return ".".join(str(part) for part in parts)


def current_built_version() -> tuple[int, ...]:
    """Highest version across all ``psycopg-*`` git tags."""
    output = subprocess.run(
        ["git", "tag", "-l", "psycopg-*"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    built = []
    for line in output.splitlines():
        match = TAG_RE.match(line.strip())
        if match and NUM_RE.match(match.group(1)):
            built.append(parse(match.group(1)))
    return max(built) if built else (0,)


def latest_pypi_version() -> tuple[int, ...]:
    """Latest stable, non-yanked psycopg release on PyPI."""
    with urllib.request.urlopen(PYPI_URL, timeout=30) as resp:
        data = json.load(resp)
    candidates = []
    for version, files in data["releases"].items():
        if not NUM_RE.match(version):
            continue
        # Skip a release whose files have all been yanked.
        if not files or all(f.get("yanked") for f in files):
            continue
        candidates.append(parse(version))
    return max(candidates)


def main() -> None:
    current = current_built_version()
    latest = latest_pypi_version()
    should_update = latest > current

    print(f"Current built version: {fmt(current)}")
    print(f"Latest PyPI version:   {fmt(latest)}")
    print(f"Update needed:         {should_update}")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as out:
            out.write(f"current={fmt(current)}\n")
            out.write(f"latest={fmt(latest)}\n")
            out.write(f"should_update={str(should_update).lower()}\n")


if __name__ == "__main__":
    main()
