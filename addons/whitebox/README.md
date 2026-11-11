# Level Whiteboxing and Snapping Suite

Grid snapping and slope maths plus a headless scene scan for off-grid blockout props and ramps too steep to climb.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/whitebox` into your project's `addons/` folder, then enable **Level Whiteboxing and Snapping Suite** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Select one or more 3D nodes in an open scene, choose a grid size and number of divisions, and press **Snap selected 3D positions**. The tool snaps each selected `Node3D`'s **local position**, skips other node types, and records one editor Undo/Redo action. It does not change rotations or save the scene. Parent transforms affect the resulting world-space grid; use the same parent coordinate system for adjacent pieces.

**Run check** audits the included `res://demo/whitebox/` fixture if present. To audit another scene, use the CLI's `--scene=<path>` and optional `--grid=<json>` arguments. Every control has a tooltip; `?` repeats the help inside the editor.

## From the command line

```sh
godot --headless --path . --script res://addons/whitebox/cli/wbx_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/whitebox/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

Grid and slope calculations live in `core/wbx_snap.gd` without editor-only APIs. The dock delegates position calculations to that core and applies the resulting properties through Godot's editor undo manager; the CLI's grid and slope audit runs headless on scene text.
