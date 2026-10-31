# World Boundary and Out-of-Bounds Auditor

Find 2D levels with no kill floor or world boundary below the geometry, open sides, and kill zones overlapping walkable floor. Enable the addon in Project Settings → Plugins and use **Audit world bounds** in the **World Bounds** dock.

The level's extent is the union of rectangle and circle collision shapes under `StaticBody2D`/`AnimatableBody2D` nodes (translation only). Kill zones are `Area2D` nodes whose name or group contains `--kill-pattern` (default `kill`); any `WorldBoundaryShape2D` also counts as a fall catcher. It reports a missing catcher below the lowest geometry, left/right edges without a wall spanning at least half the level height, and kill zones touching the top surface of a floor.

| Finding | Meaning |
|---|---|
| `missing_kill_floor` | Nothing catches a fall below the level. |
| `open_side` | A side has no tall wall. |
| `kill_zone_overlap` | A kill zone touches walkable floor. |

## Command line

```sh
godot --headless --path . --script res://addons/world_bounds/cli/wba_cli.gd -- \
  --scene=res://demo/gameplay/arena.tscn --fail-on=missing_kill_floor
```

Options: `--scene=<path>` (default `res://demo/gameplay/arena.tscn`), `--out=<dir>` (default `res://reports/world_bounds`), `--kill-pattern` (name/group text marking kill zones (default kill)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `world_bounds.json` and `world_bounds.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Heuristic and 2D only: TileMap collision, polygons, rotated shapes, instanced sub-scenes and camera limits are not modelled.
- Levels designed to be left through an edge (screen transitions) will show open sides; treat as prompts.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
