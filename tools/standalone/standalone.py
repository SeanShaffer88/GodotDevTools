#!/usr/bin/env python3
"""Standalone subset runner (no Godot binary needed). Stdlib only.
Implements: naming (file/folder pattern check, mirrors naming_conventions).
Usage: python3 tools/standalone/standalone.py naming --dir=demo/naming --pattern='^[a-z][a-z0-9_]*$'
Exit: 2 on findings, 0 clean, 1 bad args.
"""
import re, sys, pathlib
def naming(root, pattern):
    rx = re.compile(pattern)
    issues = []
    for p in sorted(pathlib.Path(root).rglob("*")):
        if any(part in ("addons", "reports", "visual_reports") or part.startswith(".") for part in p.parts):
            continue
        name = p.name if p.is_dir() else p.stem
        if not rx.search(name):
            issues.append((p, name))
    for p, name in issues:
        print(f"[file_name] {p}: Name '{name}' does not match {pattern}")
    return 2 if issues else 0
def main():
    args = sys.argv[1:]
    if not args or args[0] != "naming":
        print("usage: standalone.py naming --dir=<path> [--pattern=<regex>]", file=sys.stderr)
        return 1
    root, pattern = ".", r"^[a-z][a-z0-9_]*$"
    for a in args[1:]:
        if a.startswith("--dir="): root = a[6:]
        elif a.startswith("--pattern="): pattern = a[10:]
        else: print(f"Unknown argument: {a}", file=sys.stderr); return 1
    return naming(root, pattern)
if __name__ == "__main__":
    sys.exit(main())
