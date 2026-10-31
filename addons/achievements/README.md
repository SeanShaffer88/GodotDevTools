# Achievement Reachability Checker

Check achievement unlock conditions against the events and stats the game declares, including thresholds above stat caps and dependency cycles. Enable the addon in Project Settings → Plugins and use **Check achievements** in the **Achievements** dock.

Input:

```json
{"events": ["enemy_killed"], "stats": {"kills": 999999, "coins": 99999},
 "achievements": [
   {"id": "first_blood", "requires": {"event": "enemy_killed"}},
   {"id": "slayer", "requires": {"stat": "kills", "gte": 1000}},
   {"id": "completionist", "requires": {"all": ["first_blood", "slayer"]}}]}
```

`stats` maps each stat to its maximum (cap). An achievement is reachable when its event is declared, its threshold is at or below the cap, or all its dependencies are reachable.

| Finding | Meaning |
|---|---|
| `unknown_event` | An event condition names an undeclared event. |
| `unknown_stat` | A stat condition names an undeclared stat. |
| `unknown_achievement` | An `all` condition names an undefined achievement. |
| `unreachable_threshold` | A threshold exceeds the stat's cap. |
| `achievement_cycle` | Achievements depend on each other in a loop. |
| `blocked_achievement` | A meta-achievement can never unlock because a valid dependency cannot. |
| `duplicate_id` | Two achievements share an id. |

## Command line

```sh
godot --headless --path . --script res://addons/achievements/cli/ach_cli.gd -- \
  --input=res://demo/balance/achievements.json --fail-on=unreachable_threshold
```

Options: `--input=<path>` (default `res://demo/balance/achievements.json`), `--out=<dir>` (default `res://reports/achievements`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `achievements.json` and `achievements.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Declared events and caps come from your data; whether code really emits an event is not checked (pair with the Unused Signal finder).
- Platform-side rules (Steam, console trophies) are not modelled.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
