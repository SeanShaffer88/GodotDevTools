# Physics Collision Matrix Visualizer

See who collides with whom: build the layer and mask matrix from Project Settings and scene text, and flag all-vs-all bodies, redundant raycast layers and bits nobody uses.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/collision_matrix` into your project's `addons/` folder, then enable **Physics Collision Matrix Visualizer** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/collision_matrix/cli/cmv_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/collision_matrix/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/cmv_matrix.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/cmv_counter.gd`: add it to a scene (or autoload it) and it uses the very same core. The static matrix comes from Project Settings layer names and scene text; the runtime counter shows which pairs actually fire in play, so wasted mask bits become visible.
