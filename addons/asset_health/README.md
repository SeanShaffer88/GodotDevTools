# Asset Health Dashboard

Find oversized textures, duplicate files, unused resources, import-setting inconsistencies and assets that may hurt loading times.

Part of the **GodotDevTools** suite. Godot 4.3, no third-party dependencies, no network use. MIT licensed.

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
