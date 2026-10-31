# Procedural Animation Rigging Helper

Two-bone IK, FABRIK, look-at, squash-and-stretch and foot-placement solvers, validated from a rig config and drivable from a live scene.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/proc_anim` into your project's `addons/` folder, then enable **Procedural Animation Rigging Helper** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/proc_anim/cli/par_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/proc_anim/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/par_solvers.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/par_rig.gd`: add it to a scene (or autoload it) and it uses the very same core. Solvers are pure maths (analytic two-bone IK, FABRIK, look-at, volume-preserving squash-and-stretch, foot placement), so a rig config can be validated headless before it is wired to bones.
