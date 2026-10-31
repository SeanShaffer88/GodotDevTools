# Tilemap Rule and Autotile Generator

Validate Godot 4 terrain peering rule sets (asymmetric edges, missing transitions, corner conflicts) and generate the transition tile specs they need.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/tilemap_rules` into your project's `addons/` folder, then enable **Tilemap Rule and Autotile Generator** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/tilemap_rules/cli/tmr_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/tilemap_rules/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/tmr_rules.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. Generated transition specs are data for an artist or an import script; applying them to a TileSet stays a deliberate human step.
