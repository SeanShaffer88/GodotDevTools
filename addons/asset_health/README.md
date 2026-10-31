# Asset Health Dashboard

Find oversized textures, duplicate files, unused resources, import-setting inconsistencies and assets that may hurt loading times.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/asset_health` into your project's `addons/` folder, then enable **Asset Health Dashboard** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Run scans every file in the project: textures over 2048x2048 (with estimated video memory), byte-identical duplicates, files nothing references, import settings that differ between files of the same kind, and very large files that stall loading. Files under addons/ are tooling and are skipped.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/asset_health/cli/ahd_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.

## Import presets and texture planning

Optionally compare `.import` metadata against a local JSON preset, and set a texture estimate budget:

```sh
godot --headless --path . --script res://addons/asset_health/cli/ahd_cli.gd -- \
  --preset=res://demo/import_preset/rules.json --texture-budget=1048576 \
  --fail-on=preset_mismatch,preset_missing,texture_budget
```

Preset format: `{"importers":{"texture":{"mipmaps/generate":true,"compress/mode":0}}}`. Each importer maps to expected Godot `[params]` values; unlisted importers and settings are not checked. Missing settings, mismatches, unreadable metadata and presets matching no importer are reported. Configure platform/project-specific rules yourself; the tool does not prescribe engine import settings or modify assets. `.import` metadata must already exist (run an editor import first). The dock exposes optional preset path and budget fields.

`--texture-budget` is in bytes; zero disables it. The report totals existing source-dimension estimates (four bytes per pixel with an approximate mipmap factor when enabled). This is **not measured GPU or resident memory**: actual imported formats, platform compression, size limits, streaming, resource sharing and runtime lifetime are not modeled. Use it for rough source-side comparison only, then validate on target hardware. Preset and aggregate-budget checks passed Godot 4.3/4.5 CI; hands-on editor verification remains.
