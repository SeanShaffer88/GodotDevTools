# Responsive UI Previewer

Preview a UI across common screen sizes, aspect ratios, safe areas and stretch settings, directly inside the editor.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/responsive_ui` into your project's `addons/` folder, then enable **Responsive UI Previewer** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

**Run check** estimates saved scene rectangles against nine screen sizes and the project's configured stretch settings; it does not execute or fully lay out the scenes. It flags possible safe-area overflow and small controls for review.

For visual previews, enter the `res://` path of a trusted scene with a `Control` or `CanvasLayer` root and press **Preview scene**. Three non-interactive panes render separate instances at desktop, small-window and portrait-phone sizes. Instantiating a scene can run its constructors and `@tool` scripts, so do not preview untrusted projects. The panes do not simulate device safe areas, project window stretch, runtime input, or all game state; verify the actual game on target devices.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/responsive_ui/cli/ruip_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The static estimate lives in `core/` with no editor-only APIs, so the dock and CLI use the same check. The visual panes are an editor-side rendering aid, separate from that estimate.
