#!/usr/bin/env python3
"""Build installable addon zips without publishing a release."""

import argparse
import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

from release_manifest import ROOT, ManifestError, archive_name, load_manifest, validate_tag


def collect_files(root, manifest):
    """Collect regular addon files and include the MIT notice in every addon."""
    root = Path(root)
    license_file = root / "LICENSE"
    if license_file.is_symlink() or not license_file.is_file():
        raise ManifestError("the repository LICENSE must be a regular file")
    license_text = license_file.read_bytes()

    def walk_error(exc):
        raise ManifestError(f"cannot read addon tree: {exc}") from exc

    result = {}
    for folder in manifest:
        addon = root / "addons" / folder
        entries = []
        seen = set()
        for directory, dirs, files in os.walk(addon, followlinks=False, onerror=walk_error):
            dirs.sort()
            files.sort()
            for name in dirs + files:
                path = Path(directory) / name
                if path.is_symlink():
                    raise ManifestError(f"symlinks cannot be packaged: {path}")
                if "\\" in name or any(ord(char) < 32 for char in name):
                    raise ManifestError(f"non-portable archive path: {path}")
                folded = path.relative_to(root).as_posix().casefold()
                if folded in seen:
                    raise ManifestError(f"case-insensitive archive path collision in {folder}: {path}")
                seen.add(folded)
            for name in files:
                path = Path(directory) / name
                if not path.is_file():
                    raise ManifestError(f"not a regular file: {path}")
                entries.append((path, path.relative_to(root).as_posix()))
        addon_license = addon / "LICENSE"
        license_name = f"addons/{folder}/LICENSE"
        if addon_license.exists():
            if license_name not in {name for _, name in entries}:
                raise ManifestError(f"case-insensitive archive path collision in {folder}: {license_name}")
            if not addon_license.is_file() or addon_license.read_bytes() != license_text:
                raise ManifestError(f"{addon_license} differs from the repository LICENSE")
        else:
            if license_name.casefold() in seen:
                raise ManifestError(f"case-insensitive archive path collision in {folder}: {license_name}")
            entries.append((license_file, license_name))
        result[folder] = sorted(entries, key=lambda entry: entry[1])
    return result


def _write_archive(path, entries):
    # Fixed timestamps and a stable order avoid host-clock-dependent archives.
    with zipfile.ZipFile(path, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for source, name in entries:
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3  # Unix file modes for extractors that support them.
            mode = 0o755 if source.stat().st_mode & 0o111 else 0o644
            info.external_attr = (0o100000 | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with source.open("rb") as incoming, archive.open(info, "w") as outgoing:
                shutil.copyfileobj(incoming, outgoing)
    with zipfile.ZipFile(path) as archive:
        if archive.namelist() != [name for _, name in entries] or archive.testzip() is not None:
            raise ManifestError(f"archive failed verification: {path.name}")


def build(root, out, tag):
    root = Path(root).resolve()
    validate_tag(tag)
    manifest = load_manifest(root)
    files = collect_files(root, manifest)
    out_arg = Path(out).absolute()
    if out_arg.is_symlink():
        raise ManifestError(f"output directory cannot be a symlink: {out_arg}")
    out = out_arg.resolve()
    addons = (root / "addons").resolve()
    if out == addons or addons in out.parents:
        raise ManifestError("output directory cannot be inside addons/")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        raise ManifestError(f"output directory must be absent or empty: {out}")
    out.parent.mkdir(parents=True, exist_ok=True)

    # Stage everything first, so a failed build doesn't leave partial release assets.
    with tempfile.TemporaryDirectory(prefix=".gdt-release-", dir=out.parent) as tmp:
        stage = Path(tmp)
        suite_entries = []
        for folder, stem in manifest.items():
            entries = files[folder]
            _write_archive(stage / archive_name(stem, tag), entries)
            suite_entries.extend(entries)
        suite_entries.sort(key=lambda entry: entry[1])
        _write_archive(stage / archive_name("Suite", tag), suite_entries)
        if out.exists():
            out.rmdir()  # Refuse to overwrite even if another process added a file.
        stage.rename(out)
    return len(manifest)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True, help="release tag, e.g. v1.2.3")
    parser.add_argument("--out", default="dist", help="absent or empty output directory (default: dist)")
    args = parser.parse_args(argv)
    try:
        count = build(ROOT, args.out, args.tag)
    except (ManifestError, OSError, zipfile.BadZipFile) as exc:
        print(f"release packaging: {exc}", file=sys.stderr)
        return 1
    print(f"Built {count} addon archives and one suite archive in {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
