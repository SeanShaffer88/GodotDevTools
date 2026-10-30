# Build and Export Doctor

Diagnose export failures and configuration mistakes, explain likely causes, and suggest targeted fixes before a release build.

Part of the **GodotDevTools** suite. Godot 4.3, no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/export_doctor` into your project's `addons/` folder, then enable **Build and Export Doctor** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Run before every release build. It checks the main scene, icon and autoload paths, that every script loads, the export presets (paths, icons), whether export templates for this engine version are installed, and project feature tags. Every problem comes with its likely cause and a targeted fix in plain words.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/export_doctor/cli/bed_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
