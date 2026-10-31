# Memory Leak and Orphan Node Hunter

Static scan for orphan-node patterns, RefCounted reference circles and signal holds; the runtime watcher counts real orphans in a live session.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/leak_hunter` into your project's `addons/` folder, then enable **Memory Leak and Orphan Node Hunter** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/leak_hunter/cli/mlh_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/leak_hunter/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/mlh_scanner.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/mlh_watch.gd`: add it to a scene (or autoload it) and it uses the very same core. Findings are suspects for a human or the runtime watcher to confirm, never a verdict - the project rule for this tool is to flag, not to guess.
