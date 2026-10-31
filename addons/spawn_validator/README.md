# Spawn Point and Encounter Validator

Check 2D spawn points for being inside solid collision, too close together, or off the navigation mesh. Enable the addon in Project Settings → Plugins and use **Validate spawns** in the **Spawn Points** dock.

Spawn points are nodes in a group whose name contains `--spawn-pattern` (default `spawn`), or whose own name contains it. Each is checked against the rectangle and circle collision shapes under `StaticBody2D`/`AnimatableBody2D` nodes, against the other spawns for `--min-spacing`, and (with `--nav`) against a baked `NavigationPolygon`. World positions add up parent `position` values.

| Finding | Meaning |
|---|---|
| `blocked_spawn` | A spawn is inside solid collision. |
| `crowded_spawns` | Two spawns are closer than `--min-spacing`. |
| `off_nav_spawn` | A spawn is off the navmesh. |
| `no_spawns` | No spawn points found. |

## Command line

```sh
godot --headless --path . --script res://addons/spawn_validator/cli/spv_cli.gd -- \
  --scene=res://demo/gameplay/arena.tscn --fail-on=blocked_spawn
```

Options: `--scene=<path>` (default `res://demo/gameplay/arena.tscn`), `--out=<dir>` (default `res://reports/spawn_validator`), `--min-spacing` (minimum distance between spawns (default 32)), `--spawn-pattern` (group or name text marking spawns (default spawn)), `--nav` (optional baked NavigationPolygon .tres; spawns must lie on it), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `spawn_validator.json` and `spawn_validator.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Translation only: rotated or scaled bodies and shapes, polygons, TileMap collision and instanced sub-scenes are not modelled.
- Encounter composition (which enemies, how many) is out of scope; see the Wave Spawner Budget Planner.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
