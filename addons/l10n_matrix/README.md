# Localization Matrix and In-Context Previewer

Key-by-locale completeness matrix, overflow-risk lengths, plural-rule checks, orphan tr() keys and unused table entries.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/l10n_matrix` into your project's `addons/` folder, then enable **Localization Matrix and In-Context Previewer** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/l10n_matrix/cli/lmx_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/l10n_matrix/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/lmx_matrix.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. No machine translation and no network, by project rule: the in-context half is preview data (completeness, length risk, plural forms) rendered next to the source strings.
