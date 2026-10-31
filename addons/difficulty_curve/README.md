# Difficulty Curve Analyzer

Compare enemy power with player power level by level and flag spikes, dips and impossible stretches. Enable the addon in Project Settings → Plugins and use **Analyze difficulty** in the **Difficulty Curve** dock.

Input: `{"levels": [{"level": 1, "enemy_power": 10, "player_power": 12}, ...]}`, sorted by level. For each level it computes `enemy_power / player_power` and compares neighbours. What "power" means (DPS × HP, a gear score, a designer's rating) is up to your balance sheet.

| Finding | Meaning |
|---|---|
| `difficulty_spike` | The ratio rises by more than `--spike` from the previous level. |
| `difficulty_dip` | The ratio falls by more than `--dip` (often a deliberate breather). |
| `too_hard` | The ratio exceeds `--max-ratio`. |
| `level_order` | Levels are not in ascending order. |

## Command line

```sh
godot --headless --path . --script res://addons/difficulty_curve/cli/dca_cli.gd -- \
  --input=res://demo/balance/difficulty.json --fail-on=difficulty_spike
```

Options: `--input=<path>` (default `res://demo/balance/difficulty.json`), `--out=<dir>` (default `res://reports/difficulty_curve`), `--spike` (ratio increase between consecutive levels that counts as a spike (default 0.25)), `--dip` (ratio decrease that counts as a dip (default 0.25)), `--max-ratio` (ratio above which a level is too hard (default 1.5)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `difficulty_curve.json` and `difficulty_curve.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- A single ratio cannot capture skill, build variety or encounter design; use it to find suspicious levels for playtesting.
- Thresholds are absolute ratio differences; tune them to your scale.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
