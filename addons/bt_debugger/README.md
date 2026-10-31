# Behaviour Tree and State Machine Debugger

Validate and run JSON behaviour definitions (selector/sequence trees, guarded transitions, blackboards) with a full decision trace.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/bt_debugger` into your project's `addons/` folder, then enable **Behaviour Tree and State Machine Debugger** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/bt_debugger/cli/btd_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/bt_debugger/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/btd_machine.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/btd_agent.gd`: add it to a scene (or autoload it) and it uses the very same core. Because the dock and the live agent share one interpreter and one definition format, the trace you study in the editor is the trace the shipped behaviour produces.
