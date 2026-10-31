# Natural-Language Scene Search

Search project content with queries like 'find enemies that use a patrol state' or 'show scenes with a door interaction', using project metadata and code indexing.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/scene_search` into your project's `addons/` folder, then enable **Natural-Language Scene Search** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Type a plain-words query (for example: find enemies that use a patrol state) and Run. The index covers scene node names and types, script functions, variables, class names and file names. Every result says why it matched, so the ranking can be checked. Matching is rule-based and offline - it matches the words in your project, not synonyms.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/scene_search/cli/nlss_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
