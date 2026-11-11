# Android Touch and Safe Area Audit

Review **resolved** touch-target rectangles from a captured screen: size in logical dp, proximity, overlaps and whether they fit the reported display safe area. The analyzer reads a JSON snapshot, not scene files, so it does not guess container layout or execute your project in the editor/CLI. A small optional runtime helper captures visible controls after the game has laid them out.

## Capture a screen

Copy `addons/android_touch_audit` into your project and enable **Android Touch and Safe Area Audit**. For a debug build, call the helper after the UI is fully laid out, once for each screen and orientation you want to review:

```gdscript
const TouchCapture = preload("res://addons/android_touch_audit/runtime/ata_capture.gd")

# Call from your own debug UI after the menu is visible and layout has settled.
func save_touch_snapshot() -> void:
    await get_tree().process_frame
    var capture = TouchCapture.new()
    var snapshot: Dictionary = capture.capture(get_tree().current_scene)
    var path := "user://touch_snapshot.json"
    var err: Error = capture.save_snapshot(snapshot, path)
    if err == OK:
        print("Touch snapshot: ", ProjectSettings.globalize_path(path))
    else:
        push_warning("Could not save touch snapshot: %s" % err)
```

The helper does not run or write automatically. Copy the resulting file from the test device to your development machine by an appropriate authorized debug/file-transfer method, then select it in the **Android Touch Audit** dock. The dock's default `user://` is the **editor project's** user directory, not the device's. Node paths can reveal internal names; review snapshots before sharing. `capture()` includes enabled, visible `BaseButton` controls and other visible `Control` nodes explicitly placed in group `touch_target`; controls with mouse filter Ignore are excluded. The returned `capture.skipped_other_viewport` counts eligible controls in other viewports that are not sampled.

A manually measured snapshot can also be supplied. All rectangles must use the **same screen-space pixels** for the captured orientation, with origin at the screen's top left:

```json
{
  "version": 1,
  "screen": {"size_px": [1080, 2400], "safe_area_px": [0, 100, 1080, 2200], "density_dpi": 320},
  "targets": [
    {"path": "/Game/Menu/Play", "rect_px": [100, 200, 120, 100], "axis_aligned": true}
  ]
}
```

`safe_area_px` and `rect_px` are `[x, y, width, height]`. The optional `axis_aligned` defaults to true; set it false if a bounding box represents a rotated/skewed control. The runtime helper marks such transforms automatically. Target paths must be unique. Screen and safe-area sizes must be positive and the safe area must fit in the screen.

## Command line

```sh
godot --headless --path . --script res://addons/android_touch_audit/cli/ata_cli.gd -- \
  --input=/path/to/copied-touch-snapshot.json --min-dp=48 --gap-dp=8 \
  --fail-on=small_target,outside_safe_area,overlap
```

In this repository, use `res://demo/android_dev/touch_snapshot.json` for an example with findings.

`--input` defaults to `user://touch_snapshot.json`; `--min-dp` defaults to 48, `--gap-dp` to 8 (0 disables gap checks), and `--out` to `res://reports/android_touch_audit`. The thresholds are **configurable review heuristics**, not a claim of compliance. The tool uses `dp = px * 160 / density_dpi`. Android's reported logical density is not a physical measurement. Reports are `android_touch_audit.json` and `.md`. `--fail-on` accepts comma-separated finding kinds, `issues`, or `errors`. Exit **0** on success without selected findings, **2** for selected findings, or **1** for bad arguments, invalid/unreadable snapshots or write errors. `--help` lists options.

| Finding | Meaning |
|---|---|
| `small_target` | Either rectangle dimension is below the chosen dp minimum. |
| `outside_safe_area` | A rectangle extends outside the supplied safe area. |
| `overlap`, `close_targets` | Axis-aligned rectangles overlap or their shortest edge/corner distance is below the chosen gap. |
| `unsupported_transform` | Rotation or skew makes the bounding box unreliable; geometry checks for that target are skipped. |
| `pair_findings_truncated` | More than 2,000 pair findings; the omitted count is reported. Split the capture. |
| `no_targets`, `viewport_targets_skipped` | No targets supplied, or the runtime helper skipped eligible controls in other viewports. |
| `bad_input` | Invalid snapshot, threshold, missing file, more than 500 targets, or input over 5 MB; always exits 1. |

## Limits

- The helper samples the main window's viewport only. `SubViewport`/other window controls and `TouchScreenButton`/other `Node2D` hit shapes are not analyzed. Custom touch controls must be opted in and have an appropriate `Control` rectangle. Hidden, disabled or Ignore-filter controls are skipped.
- Rectangles are transformed from control-local coordinates through the canvas and viewport to screen coordinates. Clipping, occlusion, z-order, expanded/custom hit tests, embedded overlays, gestures and whether touch events actually reach a control are **not** measured. Overlap can be intentional. Rotated/skewed targets are reported, not sized from their bounding boxes.
- The helper uses Godot's screen size, Android logical `screen_get_dpi()` and `get_display_safe_area()` at capture time. System bars, window modes, cutouts, stretch settings and Android/Godot versions can change the coordinate relationship. Check the captured values against the actual device; use a manually measured snapshot if necessary. It is not a physical-size measurement or a substitute for real touch testing.
- No scene instantiation, network, device connection or automatic project modification. `save_snapshot` and CLI report writes are explicit. Headless synthetic tests are provided; the capture helper has not been verified on Android hardware.
