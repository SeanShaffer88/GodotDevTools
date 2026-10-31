# Mobile Thermal and Battery Drain Emulation Dock

Documented-estimate RC thermal model with frame-budget and battery-hours comparisons across workload changes and estimated device profiles.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/thermal_sim` into your project's `addons/` folder, then enable **Mobile Thermal and Battery Drain Emulation Dock** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/thermal_sim/cli/thm_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/thermal_sim/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/thm_model.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. Every device number is a documented estimate: use the output to rank workload changes on the same guessed hardware, never as an absolute prediction.
