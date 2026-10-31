# Visual Regression Testing

Capture scene screenshots across resolutions and compare them with approved baselines, highlighting pixel-level differences.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

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

## Screenshot review queue

Generate a review queue alongside the visual report with `--review-queue`:

```sh
godot --headless --path . --script res://addons/visual_regression/cli/vrt_cli.gd -- \
  --baseline=res://demo/visual/baselines --current=res://demo/visual/current --review-queue
godot --headless --path . --script res://addons/visual_regression/cli/vrt_review_cli.gd -- \
  --queue=res://visual_reports/review_queue.json --out=res://visual_reports/review_decided.json \
  --name=menu__320x240.png --decision=approved --reviewer=reviewer --note="Reviewed change"
```

The queue lists non-passing comparisons with SHA-256 fingerprints. Missing or unreadable captures are blocked. Recording an `approved` or `rejected` decision requires a reviewer and rechecks both images against their recorded fingerprints; a changed image requires a new queue. A decision appends reviewer, note, timestamp and fingerprints to the item's history in a **new, distinct JSON file**. To add another decision, use that file as the next `--queue` and choose another `--out` file. The dock displays the number of review items; inspect the screenshots and highlights separately.

**A review decision is metadata only.** It never copies or changes baselines. The existing manual approval process remains separate; recheck file hashes before any later promotion. Queue files are editable local JSON, not tamper-proof or identity-verified audit records. History lasts only if the output files are preserved; regenerating a queue starts a new history. New review features and the dock require Godot CI and hands-on editor verification.
