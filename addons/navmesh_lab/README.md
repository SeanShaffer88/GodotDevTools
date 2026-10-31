# Navigation Mesh Diagnostic Lab

Find disconnected regions, narrow passages and unreachable or off-mesh targets in a baked 2D navigation polygon. Enable the addon in Project Settings → Plugins and use **Diagnose navmesh** in the **Navmesh Lab** dock.

It reads the baked `vertices` and `polygons` of a `NavigationPolygon` (a `.tres`, or the first one inside a scene). Polygons sharing an edge are connected; every region other than the largest is reported. With `--targets`:

```json
{"agent_radius": 8, "start": [50, 50], "targets": [{"id": "treasure_room", "pos": [1000, 100]}]}
```

connecting edges shorter than the agent's diameter are narrow passages, and each target is checked for being on the mesh and in the start's region.

| Finding | Meaning |
|---|---|
| `disconnected_region` | A navmesh region is not connected to the main one. |
| `narrow_passage` | A connection narrower than the agent. |
| `unreachable_target` | A target is on the mesh but in another region. |
| `off_mesh_point` | A target is outside the mesh. |
| `no_navmesh` | No baked polygons. |

## Command line

```sh
godot --headless --path . --script res://addons/navmesh_lab/cli/nml_cli.gd -- \
  --nav=res://demo/gameplay/nav.tres --targets=res://demo/gameplay/targets.json --fail-on=unreachable_target
```

Options: `--nav=<path>` (default `res://demo/gameplay/nav.tres`), `--out=<dir>` (default `res://reports/navmesh_lab`), `--targets` (JSON {agent_radius, start: [x, y], targets: [{id, pos}]}), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `navmesh_lab.json` and `navmesh_lab.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- 2D NavigationPolygon only; 3D NavigationMesh and NavigationLinks are not read.
- Coordinates are the mesh's local space; offset targets if your NavigationRegion2D is moved.
- Edge adjacency uses shared vertex indices as baked; separately baked regions merged at runtime by edge connection margin are not joined here.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
