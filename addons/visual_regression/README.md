# Visual Regression Testing

Capture scene screenshots across resolutions and compare them with approved baselines, highlighting pixel-level differences.

Part of the **GodotDevTools** suite. Godot 4.3, no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/visual_regression` into your project's `addons/` folder, then enable **Visual Regression Testing** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Capture: list scene paths in the Capture box (comma-separated; empty means the project's main scene), set the output folder (default res://visual_current), and press **Capture now**. Each scene is instantiated in an offscreen viewport at every standard resolution, given two frames to settle, and saved as <scene>__<width>x<height>.png - the same names the compare run reads. The capture pass needs the editor's renderer, so it runs in the editor or a real game window, never headless.

Compare: put approved screenshots in res://visual_baselines with the same names and fresh captures in res://visual_current, then **Run check**. Failing pairs differ from the approved picture; the CLI writes a highlight image per failure (changed pixels in magenta). Approve a change by copying the capture over the baseline.

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/visual_regression/cli/vrt_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
