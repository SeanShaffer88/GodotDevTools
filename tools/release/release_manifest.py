"""Shared release asset names and validation for packaging and metadata."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path("tools/release/manifest.json")
TAG_PATTERN = re.compile(r"v[0-9]+\.[0-9]+\.[0-9]+\Z")
FOLDER_PATTERN = re.compile(r"[a-z0-9_]+\Z")
NAME_PATTERN = re.compile(r"[A-Za-z0-9]+\Z")


class ManifestError(ValueError):
    """The manifest, checkout or release tag cannot be packaged safely."""


def _unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ManifestError(f"duplicate manifest entry: {key}")
        result[key] = value
    return result


def validate_tag(tag):
    if not isinstance(tag, str) or not TAG_PATTERN.fullmatch(tag):
        raise ManifestError(f"invalid release tag {tag!r}; expected vMAJOR.MINOR.PATCH")
    return tag


def archive_name(stem, tag):
    validate_tag(tag)
    if not isinstance(stem, str) or not NAME_PATTERN.fullmatch(stem):
        raise ManifestError(f"invalid release asset name: {stem!r}")
    return f"GodotDevTools-{stem}-{tag}.zip"


def load_manifest(root=ROOT):
    """Return folder-to-asset-stem mapping after checking the complete checkout."""
    root = Path(root)
    try:
        entries = json.loads((root / MANIFEST).read_text(encoding="utf-8"), object_pairs_hook=_unique_pairs)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ManifestError(f"cannot read release manifest: {exc}") from exc
    if not isinstance(entries, dict) or not entries:
        raise ManifestError("release manifest must be a nonempty JSON object")

    names = {}
    for folder, stem in entries.items():
        if not isinstance(folder, str) or not FOLDER_PATTERN.fullmatch(folder):
            raise ManifestError(f"invalid addon folder in manifest: {folder!r}")
        if not isinstance(stem, str) or not NAME_PATTERN.fullmatch(stem):
            raise ManifestError(f"invalid release asset name for {folder}: {stem!r}")
        folded = stem.casefold()
        if folded == "suite":
            raise ManifestError(f"asset name for {folder} is reserved for the suite")
        if folded in names:
            raise ManifestError(f"duplicate release asset name: {names[folded]} and {folder}")
        names[folded] = folder

    addons = root / "addons"
    if not addons.is_dir() or addons.is_symlink():
        raise ManifestError(f"not an addon directory: {addons}")
    actual = set()
    for child in addons.iterdir():
        if child.is_symlink() or not child.is_dir():
            raise ManifestError(f"expected an addon directory, not {child}")
        actual.add(child.name)
    expected = set(entries)
    if actual != expected:
        missing = sorted(expected - actual)
        unlisted = sorted(actual - expected)
        raise ManifestError(f"manifest/addons mismatch: missing folders={missing}, unlisted folders={unlisted}")
    for folder in expected:
        cfg = addons / folder / "plugin.cfg"
        if cfg.is_symlink() or not cfg.is_file():
            raise ManifestError(f"missing regular plugin.cfg for {folder}")
    return dict(sorted(entries.items()))
