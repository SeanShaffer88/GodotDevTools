# Level Whiteboxing and Snapping Suite

Grid snapping and slope maths plus a headless scene scan for off-grid blockout props and ramps too steep to climb.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/whitebox` into your project's `addons/` folder, then enable **Level Whiteboxing and Snapping Suite** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/whitebox/cli/wbx_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/whitebox/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/wbx_snap.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. Snapping selections inside the live editor is dock-side work (marked Partially Verified in docs/PARITY.md); the grid and slope audit here runs headless on scene text.
