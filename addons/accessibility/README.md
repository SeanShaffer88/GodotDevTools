# Automated Accessibility Checker

Detect tiny text, low contrast, missing keyboard navigation and controls that rely only on colour.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/accessibility` into your project's `addons/` folder, then enable **Automated Accessibility Checker** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Run checks every scene: text under 14 px, text/background contrast under 4.5:1 (the WCAG formula), interactive controls that cannot take keyboard focus, and status indicators that may communicate by colour alone. Contrast is measured against a dark theme background; if your game is light-themed, set assumed_background in the checker.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/accessibility/cli/a11y_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
