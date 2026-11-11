# Asset Library + suite presets

## Suite presets (in-editor)

`addons/suite_presets` (`full`, `ci_only`, `mobile_perf`, `content`, `testing`) — preview which plugins a profile enables, apply with `--apply` (backs up `project.godot`). This avoids enabling all 138 plugins by default. See the addon README.

## Godot Asset Library publishing

`tools/assetlib/generate_assetlib.py` generates one submission JSON per tool from `plugin.cfg` into `assetlib/`. The release workflow (`.github/workflows/release.yml`) already builds per-tool zips on `v*` tags; the Asset Library flow is:

1. `python3 tools/assetlib/generate_assetlib.py`
2. Build zips (or take them from the GitHub Release).
3. Submit each tool at <https://godotengine.org/asset-library/> using its `assetlib/<tool>.json`.
4. Add the Asset Library link to the tool README.

Status: generator + checklist done; first submissions pending (external review queue). itch.io mirrors are optional and use the same zips.
