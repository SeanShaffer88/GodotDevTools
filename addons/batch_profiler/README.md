# Draw Call and Batching Profiler

Find 2D draw-call breakers: material switches, z-index interleaving and light passes in your scenes.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/batch_profiler` into your project's `addons/` folder, then enable **Draw Call and Batching Profiler** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/batch_profiler/cli/dbp_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/batch_profiler/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/dbp_profiler.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. Findings are draw-call-break suspects read from scene text, not GPU measurements - confirm in the running game with the profiler monitors.
