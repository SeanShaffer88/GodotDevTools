# Multi-Platform Input Matrix and Rebinding Suite

Matrix of actions against keyboard, mouse, gamepad and touch, with binding collisions, coverage gaps and generated remap-menu data.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/input_matrix` into your project's `addons/` folder, then enable **Multi-Platform Input Matrix and Rebinding Suite** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/input_matrix/cli/imx_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/input_matrix/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/imx_matrix.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/imx_rebind.gd`: add it to a scene (or autoload it) and it uses the very same core. Bindings serialize to the same {device, id} vocabulary the matrix reports in, so a saved rebinding layout can be re-checked for collisions before it ships.
