# Signal Flow and Event Bus Spy

Analyze recorded signal sessions: emitter-to-listener latency, dropped emissions, cascade depth, recursion and runaway emitters.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/signal_spy` into your project's `addons/` folder, then enable **Signal Flow and Event Bus Spy** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/signal_spy/cli/sgs_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/signal_spy/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/sgs_analyzer.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/sgs_bus.gd`: add it to a scene (or autoload it) and it uses the very same core. The runtime bus records sessions in the exact JSON shape the analyzer consumes, so a bug reproduced in a play session becomes a report in one CLI call.
