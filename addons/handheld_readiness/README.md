# Handheld Readiness Checklist

Check a project for small handheld screens and gamepad-only play: stretch mode, text size at the target height, gamepad bindings and focusable buttons. Enable the addon in Project Settings → Plugins and use **Check handheld readiness** in the **Handheld Readiness** dock.

It reads the project's viewport height, stretch mode and `[input]` actions, then every `.tscn` under the folder for `theme_override_font_sizes/font_size` and button `focus_mode`. Text sizes are scaled from the project viewport height to `--target-height` (default 800 px, a common handheld height) and compared with `--min-text-px` (default 12). These defaults are this tool's starting points, not platform requirements; set them from your platform's current guidance.

| Finding | Meaning |
|---|---|
| `stretch_disabled` | Stretch mode is disabled, so the UI will not scale. |
| `small_text` | A font size override is below the minimum once scaled to the target height. |
| `no_gamepad_binding` | A custom action has keyboard/mouse events but no joypad event. |
| `not_focusable` | A button has focus mode None and cannot be reached with a gamepad. |

## Command line

```sh
godot --headless --path . --script res://addons/handheld_readiness/cli/hrc_cli.gd -- \
  --dir=res://demo/shipping/handheld --project=res://demo/shipping/handheld/project_handheld.godot --fail-on=no_gamepad_binding
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/handheld_readiness`), `--project` (project file (default res://project.godot)), `--target-height` (handheld screen height in pixels (default 800)), `--min-text-px` (smallest acceptable text height on the target screen (default 12)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `handheld_readiness.json` and `handheld_readiness.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Only font size overrides are read; theme default sizes and LabelSettings are not.
- Scaling assumes a stretch mode that scales the UI with the window height.
- Built-in ui_* actions are skipped; Godot binds them to gamepads by default.
- No platform certification claim; this is a pre-check before testing on the device.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
