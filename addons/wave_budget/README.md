# Wave Spawner Budget Planner

Simulate wave definitions on a timeline and flag peaks of enemies alive and spawns per second above budget. Enable the addon in Project Settings → Plugins and use **Plan waves** in the **Wave Budget** dock.

Input:

```json
{"enemy_lifetime": {"grunt": 8},
 "waves": [{"id": "w1", "duration": 30,
   "groups": [{"enemy": "grunt", "count": 15, "interval": 2.0, "start": 0}]}]}
```

Each group spawns `count` enemies every `interval` seconds from `start`. `enemy_lifetime` is the average seconds an enemy stays alive (from playtests). The report lists each wave's spawns, peak alive count and when it happens, the most spawns within any one-second window, and the last spawn time.

| Finding | Meaning |
|---|---|
| `alive_budget` | Peak enemies alive exceeds `--max-alive`. |
| `spawn_rate_budget` | More than `--max-spawn-rate` spawns inside one second. |
| `wave_overrun` | Spawns continue past the wave's `duration`. |
| `unknown_enemy` | An enemy has no lifetime; `--default-lifetime` is used. |

## Command line

```sh
godot --headless --path . --script res://addons/wave_budget/cli/wsb_cli.gd -- \
  --input=res://demo/balance/waves.json --fail-on=alive_budget
```

Options: `--input=<path>` (default `res://demo/balance/waves.json`), `--out=<dir>` (default `res://reports/wave_budget`), `--max-alive` (enemies alive at once (default 30)), `--max-spawn-rate` (spawns in any one-second window (default 5)), `--default-lifetime` (seconds an enemy with no listed lifetime stays alive (default 10)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `wave_budget.json` and `wave_budget.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Lifetimes are averages; real kill speed varies with player skill. Re-run with pessimistic lifetimes for a worst case.
- Waves are simulated independently; overlap between waves is not modelled.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
