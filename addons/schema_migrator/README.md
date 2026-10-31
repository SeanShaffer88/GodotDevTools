# Hot-Reloadable Schema and Save-Game Migrator

Version save games and migrate old saves forward with registered rename, move, default and delete ops - the registry re-reads from disk every run, so schema edits apply without a restart.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/schema_migrator` into your project's `addons/` folder, then enable **Hot-Reloadable Schema and Save-Game Migrator** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/schema_migrator/cli/smg_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/schema_migrator/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/smg_registry.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The registry is re-read from disk on every run: edit the schema file, run again, and the new rules apply without restarting anything - that is the whole hot-reload story.
