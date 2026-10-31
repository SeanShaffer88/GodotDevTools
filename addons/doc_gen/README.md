# Automated Documentation Generator for GDScript

Parse ## doc comments, signals, exports and functions from GDScript into Markdown and dependency-free HTML, reporting undocumented public API.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/doc_gen` into your project's `addons/` folder, then enable **Automated Documentation Generator for GDScript** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/doc_gen/cli/dcg_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/doc_gen/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/dcg_parser.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. Parsing is line-based and never executes or imports the scripts it documents, so it stays safe on broken, half-written or circular code.
