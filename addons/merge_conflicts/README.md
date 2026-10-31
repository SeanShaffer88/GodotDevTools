# Scene Merge Conflict Assistant

Find git conflict markers in scenes, resources and project files and explain each conflict by section, node and property. Never edits files. Enable the addon in Project Settings → Plugins and use **Explain conflicts** in the **Merge Conflicts** dock.

It scans `.tscn`, `.tres`, `project.godot`, `.cfg` and `.import` files under the folder (hidden folders, `addons/` and report folders skipped) for git conflict markers and explains each hunk using the section it falls in. It reports properties changed on both sides (with both values), ext_resource ids reused for different files (where picking either side breaks references), `load_steps` header differences (safe: take the larger), and anything else as a structural conflict. Files are never modified; resolve in your editor or merge tool.

| Finding | Meaning |
|---|---|
| `property_conflict` | Both sides set the same property(ies) differently. |
| `id_collision` | Both sides use one ext_resource id for different files. |
| `trivial_conflict` | Only the header `load_steps` differs. |
| `structural_conflict` | Nodes, resources or lines added/removed on both sides. |

## Command line

```sh
godot --headless --path . --script res://addons/merge_conflicts/cli/smc_cli.gd -- \
  --dir=res://demo/workflow/conflicts --fail-on=id_collision
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/merge_conflicts`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `merge_conflicts.json` and `merge_conflicts.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- It explains; it does not merge. Godot scene text has ordering rules, so after resolving, open the scene in the editor and re-save.
- diff3-style base sections are skipped; only ours and theirs are compared.
- Read-only: it never modifies project files.
- The demo fixture folder carries a `.gdignore` so Godot does not try to import the deliberately conflicted scene.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
