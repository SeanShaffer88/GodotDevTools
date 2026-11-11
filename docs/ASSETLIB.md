# Asset Library + suite presets

## Suite presets (in-editor)

`addons/suite_presets` (`full`, `ci_only`, `mobile_perf`, `content`, `testing`) — preview which plugins a profile enables, apply with `--apply` (backs up `project.godot`). This avoids enabling all 138 plugins by default. See the addon README.

## Godot Asset Library publishing

`tools/assetlib/generate_assetlib.py` generates one submission JSON per tool from `plugin.cfg` into `assetlib/`. The release workflow (`.github/workflows/release.yml`) already builds per-tool zips on `v*` tags; the Asset Library flow is:

1. `python3 tools/assetlib/generate_assetlib.py`
2. Build zips (or take them from the GitHub Release).
3. Submit each tool at <https://godotengine.org/asset-library/> using its `assetlib/<tool>.json`.
4. Add the Asset Library link to the tool README.

The generated `zip` field describes the local archive name built by the checklist, using the addon folder and its plugin version. It is **not** the name used by the release workflow: `.github/workflows/release.yml` uses a mapped CamelCase tool name and the release tag, which can differ from the plugin version. For example, the three Android additions would be `GodotDevTools-AndroidExportAudit-vX.Y.Z.zip`, `GodotDevTools-AndroidTouchAudit-vX.Y.Z.zip`, and `GodotDevTools-AndroidLogcatTriage-vX.Y.Z.zip` for release `vX.Y.Z`. These are naming examples, not links to an existing release. Verify the actual release asset and URL when submitting.

Status: generator + checklist done; first submissions pending (external review queue). itch.io mirrors are optional and use the same zips.
