# Cross-Platform Virtual Filesystem Mock

Resolve file operations against linux, windows, android and ios filesystem rules, and audit scripts for platform-specific path literals.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/vfs_mock` into your project's `addons/` folder, then enable **Cross-Platform Virtual Filesystem Mock** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/vfs_mock/cli/vfm_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/vfs_mock/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/vfm_fs.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The mock resolves against the project's real file listing, so verdicts are real even though no platform actually boots; profiles carry honest estimate names.
