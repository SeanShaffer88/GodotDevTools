# Mesh Statistics Report

Read glTF/GLB files and report triangles, vertices, primitives and materials per file against budgets. Enable the addon in Project Settings → Plugins and use **Report mesh stats** in the **Mesh Stats** dock.

It reads every `.gltf` and `.glb` under the folder (hidden folders, `addons/` and report folders skipped) and counts from accessor metadata only: vertices from each primitive's `POSITION` accessor, triangles from the index accessor (lists, strips and fans) or vertex count without indices, and distinct materials. A mesh used by several nodes counts once per node.

| Finding | Meaning |
|---|---|
| `triangle_budget` | File triangles exceed `--max-triangles`. |
| `material_budget` | Distinct materials exceed `--max-materials`. |
| `large_primitive` | A primitive has more than 65535 vertices. |
| `bad_gltf` | Not readable glTF 2.0 JSON. |

## Command line

```sh
godot --headless --path . --script res://addons/mesh_stats/cli/msr_cli.gd -- \
  --dir=res://demo/rendering --max-triangles=5000 --fail-on=triangle_budget
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/mesh_stats`), `--max-triangles` (triangles per file (default 50000)), `--max-materials` (materials per file (default 8)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `mesh_stats.json` and `mesh_stats.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Counts come from the source file; Godot import options (LOD generation, mesh splitting) change what ships.
- Skinning, morph targets and texture sizes are not weighed.
- `.blend`, `.fbx` and `.obj` sources are not read; export glTF to audit them.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
