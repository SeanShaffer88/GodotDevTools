# Controller Glyph and Prompt Validator

Check that every action referenced in prompt text exists, is bound for each device family, and has a glyph image for each device. Enable the addon in Project Settings → Plugins and use **Validate prompts** in the **Glyphs and Prompts** dock.

It collects action tokens (default `[action:jump]`; change with `--token`, group 1 = action name) from CSV, PO, script, scene and JSON files under the folder. Every token must name an InputMap action of `--project` (built-in `ui_*` actions are assumed). Each subfolder of the glyph root (`--glyphs`, default the same folder) is a device: `keyboard`, `mouse`, `kbm` and `pc` are keyboard/mouse devices; any other name is a gamepad. For every prompted action and device, the action needs a binding of that family and a glyph `<device>/<action>.png` (or `.svg`/`.webp`).

| Finding | Meaning |
|---|---|
| `unknown_action` | A prompt names an action the InputMap lacks. |
| `missing_glyph` | Bound for the device but no glyph image. |
| `unbound_for_device` | Prompted on a device family with no binding. |

## Command line

```sh
godot --headless --path . --script res://addons/controller_glyphs/cli/cgp_cli.gd -- \
  --dir=res://demo/glyphs --project=res://demo/ci/input_actions.godot --fail-on=unknown_action
```

Options: `--dir=<path>` (default `res://demo/glyphs`), `--out=<dir>` (default `res://reports/controller_glyphs`), `--glyphs` (glyph root with one folder per device, e.g. keyboard/, xbox/ (default: the prompts folder)), `--project` (project file with the InputMap (default res://project.godot)), `--token` (regex whose group 1 is the action name (default \[action:([a-z0-9_]+)\])), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `controller_glyphs.json` and `controller_glyphs.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Prompts assembled in code from action names are not seen; use the token form in text.
- Device folders are classified by name only; per-controller layouts (face button order) are not checked.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
