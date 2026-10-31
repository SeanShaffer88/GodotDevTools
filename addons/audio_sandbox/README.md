# Audio Bus and Dynamic Mixing Sandbox

Simulate ducking, reverb zones and voice budgets from pure data on a fixed 10 ms clock, and catch mixing designs that fight themselves.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/audio_sandbox` into your project's `addons/` folder, then enable **Audio Bus and Dynamic Mixing Sandbox** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/audio_sandbox/cli/aud_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/audio_sandbox/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/aud_mixer.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The simulation is deterministic 10 ms-step data, not an audio driver; listen in-engine before shipping a curve, but tune the numbers here first.
