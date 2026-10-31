# Smart Prefab and Variant Instance Manager

Classify prefab instance overrides, expose drift (dead and hiding), and generate rollback plans that only --apply ever writes.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/prefab_guard` into your project's `addons/` folder, then enable **Smart Prefab and Variant Instance Manager** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/prefab_guard/cli/pfg_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/prefab_guard/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/pfg_diff.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. Rollback plans are generated as data and nothing is written to a scene unless the CLI runs with explicit --apply, because scene files are source code.
