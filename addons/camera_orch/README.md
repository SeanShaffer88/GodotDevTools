# Camera Shake, Transition and Framing Orchestrator

Seeded deterministic camera shake, ease-curve transitions and deadzone framing maths, with config validation and preview samples.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/camera_orch` into your project's `addons/` folder, then enable **Camera Shake, Transition and Framing Orchestrator** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/camera_orch/cli/cor_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/camera_orch/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/cor_motion.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/cor_camera.gd`: add it to a scene (or autoload it) and it uses the very same core. Shakes come from a hand-rolled seeded value noise, so the same seed replays the same shake on any platform - a reported weird shake becomes reproducible.
