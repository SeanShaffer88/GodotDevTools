#!/usr/bin/env python3
"""Standalone subset runner (no Godot binary needed). Stdlib only.
Implements: naming (file/folder pattern check, mirrors naming_conventions).
Usage: python3 tools/standalone/standalone.py naming --dir=demo/naming --pattern='^[a-z][a-z0-9_]*$'
Exit: 2 on findings, 0 clean, 1 bad arguments or scan root.
"""
import pathlib
import re
import sys


EXCLUDED = {"addons", "reports", "visual_reports"}
SIDECAR_EXTENSIONS = {"import", "uid"}


def _basename(name: str) -> str:
    # String.get_basename() removes the last dot even if it is trailing.
    return name.rsplit(".", 1)[0] if "." in name else name


def _extension(name: str) -> str:
    return name.rsplit(".", 1)[1] if "." in name else ""


def _is_generated_sidecar(path: pathlib.Path, directory: bool) -> bool:
    """Match Godot's file.ext.import and file.ext.uid metadata sidecars."""
    name = path.name
    return (
        not directory
        and _extension(name).lower() in SIDECAR_EXTENSIONS
        and bool(_extension(_basename(name)))
    )


def naming(root: str, pattern: str) -> int:
    if not pattern:
        print("Invalid naming pattern: pattern must not be empty", file=sys.stderr)
        return 1
    try:
        rx = re.compile(pattern)
    except re.error as exc:
        print(f"Invalid naming pattern: {exc}", file=sys.stderr)
        return 1
    base = pathlib.Path(root)
    if not base.is_dir():
        print(f"Cannot open scan directory: {root}", file=sys.stderr)
        return 1
    issues = []
    for path in sorted(base.rglob("*")):
        if any(part in EXCLUDED or part.startswith(".") for part in path.relative_to(base).parts):
            continue
        directory = path.is_dir()
        if _is_generated_sidecar(path, directory):
            continue
        name = path.name if directory else _basename(path.name)
        if not rx.search(name):
            issues.append((path, name, "directory_name" if directory else "file_name"))
    for path, name, kind in issues:
        print(f"[{kind}] {path}: Name '{name}' does not match {pattern}")
    return 2 if issues else 0


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] != "naming":
        print("usage: standalone.py naming --dir=<path> [--pattern=<regex>]", file=sys.stderr)
        return 1
    root, pattern = ".", r"^[a-z][a-z0-9_]*$"
    for arg in args[1:]:
        if arg.startswith("--dir="):
            root = arg[6:]
        elif arg.startswith("--pattern="):
            pattern = arg[10:]
        else:
            print(f"Unknown argument: {arg}", file=sys.stderr)
            return 1
    return naming(root, pattern)


if __name__ == "__main__":
    sys.exit(main())
