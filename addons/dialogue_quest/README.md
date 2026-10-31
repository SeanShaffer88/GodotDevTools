# Dialogue and Quest Debugger

Show dialogue branches and quest dependencies as a graph, simulate choices, and inspect which conditions activate.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/dialogue_quest` into your project's `addons/` folder, then enable **Dialogue and Quest Debugger** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Dialogue/quest JSON files anywhere in the project are found automatically. **Run check** lists branches pointing at missing nodes, unreachable writing, unmarked dead ends and quest dependency problems, and fills the drawn branch graph below the dialogue picker: boxes are nodes (green outline = start, blue = marked ending, orange = carries a warning from the report, red dashed = a choice target that does not exist), arrows are choices, and `[if]` on an arrow means the choice has a condition. The layout is deterministic - layers are breadth-first depth from the start, unreachable nodes park below the deepest layer.

The core's simulate(dialogue, picks, state) plays a conversation: it evaluates each choice's condition against the state you give it and applies effects, so you can see exactly which branches open.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/dialogue_quest/cli/dqd_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
