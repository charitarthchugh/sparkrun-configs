#!/usr/bin/env python3
"""Validate the required scalar mappings in the registry manifest."""

from __future__ import annotations

import re
import sys
from pathlib import Path


REQUIRED_MAPPINGS = {
    "name": "charitarth",
    "recipes": "recipes",
    "tuning": "tuning",
    "benchmarks": "benchmarking",
    "mods": "mods",
    "enabled": "true",
    "visible": "true",
}


def has_scalar_mapping(manifest: str, key: str, value: str) -> bool:
    list_item = r"(?:-\s+)?" if key == "name" else ""
    pattern = rf"^\s*{list_item}{re.escape(key)}:\s*{re.escape(value)}\s*(?:#.*)?$"
    return re.search(pattern, manifest, re.MULTILINE) is not None


def main() -> int:
    manifest_path = Path(__file__).resolve().parents[1] / ".sparkrun" / "registry.yaml"
    try:
        manifest = manifest_path.read_text(encoding="utf-8")
    except OSError as error:
        print(f"unable to read registry manifest: {error}", file=sys.stderr)
        return 1

    missing = [
        f"{key}: {value}"
        for key, value in REQUIRED_MAPPINGS.items()
        if not has_scalar_mapping(manifest, key, value)
    ]
    if missing:
        print("missing mappings:", file=sys.stderr)
        for mapping in missing:
            print(f"  {mapping}", file=sys.stderr)
        return 1

    print("registry manifest valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
