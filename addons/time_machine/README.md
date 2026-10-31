# Game-State Time Machine

Record inputs and state snapshots so you can rewind a bug, inspect variables, and replay the exact sequence that caused it. Includes an in-game recorder node.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/time_machine` into your project's `addons/` folder, then enable **Game-State Time Machine** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

In game: add the Time Machine node (addons/time_machine/runtime/gstm_node.gd), register state providers/restorers, and it records every physics frame. Save a session, then this dock (or the CLI) verifies the session file so it can be replayed exactly. rewind_to(frame) restores a snapshot; diff_states(a, b) shows which variables changed.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/time_machine/cli/gstm_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
