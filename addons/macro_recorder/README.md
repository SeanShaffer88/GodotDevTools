# Editor Action Macro Recorder

Record Inspector property edits in the editor as a macro, preview what it would change in any scene, and apply it from the command line with an explicit flag. Enable the addon in Project Settings → Plugins and use **Validate macro** in the **Macros** dock.

**Record** in the editor: press *Start recording* in the **Macros** dock, edit properties in the Inspector on nodes of the open scene, press *Stop*, then *Save* to write the macro JSON. *Preview on scene* lists what the macro would change in the scene that is open.

Macro format (hand-editable; replace `node` with a `selector` to generalize a recorded step):

```json
{"name": "Center labels", "steps": [
  {"selector": {"type": "Label"}, "property": "horizontal_alignment", "value": 1},
  {"node": "Title", "property": "theme_override_font_sizes/font_size", "value": 32},
  {"node": "Player", "property": "position", "value": {"var": "Vector2(100, 200)"}}]}
```

From the command line, `--scene=<.tscn>` previews the changes (old → new) and `--apply` writes them into that scene file. Without `--apply` nothing is modified.

| Finding | Meaning |
|---|---|
| `change_preview` | A change the macro makes (old -> new). |
| `step_unmatched` | A step matches no node. |
| `unknown_property` | The node has no such property. |
| `bad_macro` | Malformed macro (exit 1). |
| `applied` | With --apply: changes were written. |

## Command line

```sh
godot --headless --path . --script res://addons/macro_recorder/cli/eam_cli.gd -- \
  --macro=res://demo/macros/center_labels.json --scene=res://demo/workflow/drift/menu.tscn --fail-on=step_unmatched
```

Options: `--macro=<path>` (default `res://demo/macros/center_labels.json`), `--out=<dir>` (default `res://reports/macro_recorder`), `--scene` (scene to preview (or apply) the macro on), `--apply` (write the changes into the scene file (otherwise preview only)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `macro_recorder.json` and `macro_recorder.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Records property edits made in the Inspector only; node creation, reparenting, signals and script edits are not recorded.
- --apply re-saves the scene through Godot, which can reorder or normalize its text; commit before applying and review the diff.
- The recording dock needs a hands-on editor session to verify; preview/apply logic is covered by headless tests.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
