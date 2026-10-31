# Object Pool Advisor

Finds scenes that are spawned often and die young, and ranks them as object-pool candidates. Enable the addon in Project Settings → Plugins and press **Find pool candidates** in the **Pool Advisor** dock.

The scan reads every `.gd` and `.tscn` under `res://` (skipping hidden folders, `addons/` and report folders) and finds each `.instantiate()` call. It resolves the spawned scene from `preload()`/`load()` constants and variables, or from a direct `preload("...").instantiate()`, and checks whether that scene's root script calls `queue_free()` on itself.

Each spawn site gets a score:

| Signal | Points |
|---|---|
| Runs in a per-frame/input callback (`_process`, `_physics_process`, `_input`, ...) | 3 |
| Runs in a repeating handler (name contains fire/shoot/spawn/emit/attack/burst, `_on_*timeout`, `_on_*tick`, or connected to a `timeout` signal) | 2 |
| Inside a `for`/`while` loop | 1 |
| The spawned scene frees itself | 2 |
| Recorded spawn rate at or above `--rate-threshold` (default 5/s) | 3 |

| Finding | Meaning |
|---|---|
| `pool_candidate` | Score at or above `--min-score` (default 4). |
| `hot_spawn` | Per-frame spawn that did not reach the candidate score. |
| `burst_spawn` | Spawn inside a loop (often fine for one-off level setup). |
| `unresolved_spawn` | The spawned scene cannot be worked out statically. |
| `high_spawn_rate` | A recorded counts file shows a scene spawning at or above the threshold. |
| `bad_counts` | The counts file is malformed (CLI exit 1). |

## Measured evidence (optional)

`runtime/opa_counter.gd` is a node you can add as an autoload during a play session. It counts instanced scenes entering and leaving the tree by `scene_file_path`; call `save_counts()` (default `user://pool_counts.json`) before quitting. Set `enabled = false` or remove the autoload for shipped builds. Counts file format:

```json
{"seconds": 60.0, "scenes": {"res://bullet.tscn": {"spawned": 900, "freed": 897}}}
```

## Command line

```sh
godot --headless --path . --script res://addons/pool_advisor/cli/opa_cli.gd -- \
  --dir=res://demo/pooling --counts=res://demo/pooling/counts.json --fail-on=pool_candidate
```

Options: `--dir`, `--out` (default `res://reports/pool_advisor`), `--counts=<json>`, `--min-score=<n>`, `--rate-threshold=<spawns/s>`, `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `pool_advisor.json` and `pool_advisor.md`. Exit 2 when a `--fail-on` kind is found; 1 for unreadable input, a bad counts file, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Pattern-based reading of GDScript, not a parser: spawns through helper functions, `duplicate()`, `Node.new()` or C# are not seen, and a PackedScene passed in as an argument is `unresolved_spawn`.
- "Frees itself" only checks the scene's root script for a bare or `self.` `queue_free()`; freeing from a parent or a child script is not detected.
- Scores rank suspects; they are not measured cost. Profile before and after pooling.
- The runtime counter counts tree entry/exit, not allocation; a node removed and re-added is counted twice. It has unit coverage only; a live game session is pending.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
