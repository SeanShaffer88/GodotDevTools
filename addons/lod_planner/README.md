# LOD and Visibility Range Planner

Find invalid visibility ranges, heavy instanced meshes with no visibility range, and glTF imports with LOD generation turned off. Enable the addon in Project Settings → Plugins and use **Plan LODs** in the **LOD Planner** dock.

It reads `.tscn` scenes and model `.import` files under the folder (hidden folders, `addons/` and report folders skipped). Each node's `visibility_range_begin`/`visibility_range_end` pair is checked; nodes that instance a `.gltf`/`.glb` heavier than `--heavy-triangles` (counted from accessor metadata) without a far visibility range are listed; model imports with `meshes/generate_lods=false` are noted.

| Finding | Meaning |
|---|---|
| `invalid_range` | Visibility range end is not beyond begin, so the node never shows. |
| `no_visibility_range` | A heavy instanced model has no far visibility range. |
| `lods_disabled` | A model import has LOD generation off. |

## Command line

```sh
godot --headless --path . --script res://addons/lod_planner/cli/lod_cli.gd -- \
  --dir=res://demo/perf_static --fail-on=invalid_range
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/lod_planner`), `--heavy-triangles` (triangles above which an instanced model should have a visibility range (default 5000)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `lod_planner.json` and `lod_planner.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Godot's automatic mesh LODs (on by default for imports) already reduce distant cost; the no-range finding is a prompt, not an error.
- Ranges set from code and visibility parents/fade modes are not evaluated.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
