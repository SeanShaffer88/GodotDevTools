# Scene Review Snapshot Generator

Write a reproducible inventory of a scene (nodes, types, scripts, instances, stored properties) and diff it against another scene or snapshot for review. Enable the addon in Project Settings → Plugins and use **Snapshot scene** in the **Scene Snapshot** dock.

`--scene` is snapshotted into `snapshot.json` (next to the report): every node path with its type (or `instance:<scene>`), script, groups and stored properties, with `ExtResource("id")` replaced by the resource path so snapshots compare across edits. With `--compare=<older .tscn or snapshot.json>` the report lists added and removed nodes and changed types, scripts and properties. Commit snapshots of key scenes to review scene changes in pull requests as text.

| Finding | Meaning |
|---|---|
| `node_added` | A node exists only in the new version. |
| `node_removed` | A node exists only in the old version. |
| `type_changed` | A node changed type or instanced scene. |
| `script_changed` | A node's script changed. |
| `property_changed` | A stored property changed (`(default)` means not stored). |

## Command line

```sh
godot --headless --path . --script res://addons/scene_snapshot/cli/ssg_cli.gd -- \
  --scene=res://demo/workflow/snapshot/level_v2.tscn --compare=res://demo/workflow/snapshot/level_v1.tscn --fail-on=node_removed
```

Options: `--scene=<path>` (default `res://demo/workflow/snapshot/level_v2.tscn`), `--out=<dir>` (default `res://reports/scene_snapshot`), `--compare` (older scene (.tscn) or snapshot (.json) to diff against), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `scene_snapshot.json` and `scene_snapshot.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Stored properties only: values left at their defaults are not written by Godot and show as `(default)`.
- Sub-resource contents are compared by reference text, not deeply.
- Renamed nodes appear as removed + added.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
