# Procedural Generation Constraint Tester

Check generated grid layouts (one text map per seed) for an reachable exit, keys reachable before their doors, isolated pockets and dead-end share. Enable the addon in Project Settings → Plugins and use **Test layouts** in the **Procgen Constraints** dock.

Dump your generator's output for a range of seeds as text grids (`.map` or `.txt`, one per seed): `#` wall, `.` floor, `S` start, `E` exit, `K` key, `D` door (other characters count as floor). Each map is flood-filled from `S` with doors closed; if the key is reachable, doors open and the fill repeats. The summary reports the failure rate across seeds.

| Finding | Meaning |
|---|---|
| `unreachable_exit` | The exit cannot be reached. |
| `key_behind_door` | The key is only reachable through its door. |
| `isolated_pocket` | Floor cells unreachable from the start. |
| `high_dead_end_ratio` | Dead ends exceed `--max-dead-end-ratio` of reachable cells. |
| `bad_map` | No S or E in the map. |

## Command line

```sh
godot --headless --path . --script res://addons/procgen_constraints/cli/pgc_cli.gd -- \
  --dir=res://demo/gameplay/maps --fail-on=unreachable_exit,key_behind_door
```

Options: `--dir=<path>` (default `res://demo/gameplay/maps`), `--out=<dir>` (default `res://reports/procgen_constraints`), `--max-dead-end-ratio` (share of floor cells that are dead ends before flagging (default 0.25)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `procgen_constraints.json` and `procgen_constraints.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Grid connectivity with 4-way movement and one key/door pair; multiple keys, one-way drops, jumps and diagonal moves are not modelled.
- Your generator runs outside this tool; export its maps as text first (a small editor script per seed is enough).
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
