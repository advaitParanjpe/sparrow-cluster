#!/usr/bin/env python3
"""Validate the canonical active milestone without third-party dependencies."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / "milestones" / "current.md"
HEADING = re.compile(r"^#\s+Milestone\b.+", re.MULTILINE | re.IGNORECASE)
SECTION = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
ALLOWED = {"READY", "IN_PROGRESS"}


def status(text: str) -> str | None:
    match = re.search(r"^##\s+Status(?:\s+(.+?))?\s*$", text, re.MULTILINE | re.IGNORECASE)
    if not match:
        return None
    value = match.group(1)
    if value:
        return value.strip().split()[0].upper()
    remainder = text[match.end():]
    for line in remainder.splitlines():
        if line.startswith("## "):
            break
        if line.strip():
            return line.strip().split()[0].upper()
    return None


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    if not path.is_file():
        return [f"missing active milestone: {path}"]
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return [f"active milestone is empty: {path}"]
    if "MILESTONE_PLACEHOLDER" in text:
        errors.append("active milestone is still the placeholder; load a complete specification")
    if not HEADING.search(text):
        errors.append("active milestone needs a '# Milestone ...' heading")
    sections = {item.strip().lower() for item in SECTION.findall(text)}
    for required in ("completion gate", "required commands"):
        if required not in sections:
            errors.append(f"active milestone is missing '## {required.title()}'")
    current_status = status(text)
    if current_status is None:
        errors.append("active milestone needs '## Status READY' or '## Status IN_PROGRESS'")
    elif current_status == "COMPLETE":
        errors.append("active milestone already claims COMPLETE; load the next specification first")
    elif current_status not in ALLOWED:
        errors.append("active milestone status must permit execution: READY or IN_PROGRESS")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, default=DEFAULT, help="milestone file to validate")
    args = parser.parse_args()
    errors = validate(args.file)
    if errors:
        print("milestone check: failed", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"milestone check: passed ({args.file.relative_to(ROOT) if args.file.is_relative_to(ROOT) else args.file})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
