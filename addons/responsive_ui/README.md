# Responsive UI Previewer

Preview a UI across common screen sizes, aspect ratios, safe areas and stretch settings, directly inside the editor.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/responsive_ui` into your project's `addons/` folder, then enable **Responsive UI Previewer** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Run replays every UI scene in the project against 9 screen sizes (desktop, laptop, phones with notch safe areas, tablet, ultrawide, Steam Deck) using the project's real stretch settings from project.godot. Controls that land outside a safe area or shrink below 24 px are listed with the screen size that breaks them.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/responsive_ui/cli/ruip_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
