#!/usr/bin/env python3
"""Assemble a sqlite-vec wheel from a prebuilt vec0 binary. Stdlib only.

The wheel is python-version agnostic (py3-none-<platform>): the bundled binary
is dlopened by SQLite, not by CPython's extension machinery. Metadata is written
correctly here, sidestepping the sqlite-dist TODO-placeholder bug.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import zipfile
from pathlib import Path

SUMMARY = "A vector search SQLite extension that runs anywhere."
HOMEPAGE = "https://alexgarcia.xyz/sqlite-vec"
AUTHOR = "Alex Garcia"
LICENSE = "MIT OR Apache-2.0"

INIT_TEMPLATE = '''\
import os
import sqlite3
from struct import pack
from typing import List


def loadable_path() -> str:
    """Return the path to the bundled vec0 loadable extension (no suffix)."""
    return os.path.normpath(os.path.join(os.path.dirname(__file__), "vec0"))


def load(conn: sqlite3.Connection) -> None:
    """Load the sqlite-vec extension into the given connection."""
    conn.load_extension(loadable_path())


def serialize_float32(vector: List[float]) -> bytes:
    """Serialize a list of floats into the raw bytes sqlite-vec expects."""
    return pack("%sf" % len(vector), *vector)


def serialize_int8(vector: List[int]) -> bytes:
    """Serialize a list of ints into the raw bytes sqlite-vec expects."""
    return pack("%sb" % len(vector), *vector)


__version__ = "{version}"
'''


def _metadata(version: str, readme: str | None) -> str:
    body = readme if readme else SUMMARY
    return (
        "Metadata-Version: 2.1\n"
        "Name: sqlite-vec\n"
        f"Version: {version}\n"
        f"Summary: {SUMMARY}\n"
        f"Home-page: {HOMEPAGE}\n"
        f"Author: {AUTHOR}\n"
        f"License: {LICENSE}\n"
        "Description-Content-Type: text/markdown\n"
        "\n"
        f"{body}\n"
    )


def _wheel_meta(tag: str) -> str:
    return (
        "Wheel-Version: 1.0\n"
        "Generator: paperless-builder-assemble_wheel\n"
        "Root-Is-Purelib: false\n"
        f"Tag: py3-none-{tag}\n"
    )


def _hash_entry(data: bytes) -> str:
    # PEP 427 RECORD hash: sha256=<urlsafe base64, no padding>
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest())
    return f"sha256={digest.rstrip(b'=').decode()}"


def assemble(binary: Path, version: str, tag: str, out_dir: Path,
             readme: Path | None) -> Path:
    distinfo = f"sqlite_vec-{version}.dist-info"
    binary_arcname = f"sqlite_vec/{binary.name}"  # vec0.so or vec0.dylib

    readme_text = readme.read_text(encoding="utf-8") if readme else None

    files: dict[str, bytes] = {
        "sqlite_vec/__init__.py":
            INIT_TEMPLATE.format(version=version).encode(),
        binary_arcname: binary.read_bytes(),
        f"{distinfo}/METADATA": _metadata(version, readme_text).encode(),
        f"{distinfo}/WHEEL": _wheel_meta(tag).encode(),
    }

    record_lines = [
        f"{name},{_hash_entry(data)},{len(data)}"
        for name, data in files.items()
    ]
    record_lines.append(f"{distinfo}/RECORD,,")
    files[f"{distinfo}/RECORD"] = ("\n".join(record_lines) + "\n").encode()

    out_dir.mkdir(parents=True, exist_ok=True)
    wheel_path = out_dir / f"sqlite_vec-{version}-py3-none-{tag}.whl"
    with zipfile.ZipFile(wheel_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in files.items():
            z.writestr(name, data)
    return wheel_path.resolve()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary", required=True, type=Path)
    ap.add_argument("--version", required=True)
    ap.add_argument("--platform-tag", required=True, dest="tag")
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--readme", type=Path, default=None)
    args = ap.parse_args()
    wheel = assemble(args.binary, args.version, args.tag, args.out, args.readme)
    print(wheel)


if __name__ == "__main__":
    main()
