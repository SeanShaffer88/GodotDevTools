# XP Curve Planner

Turn an XP table and earn rates into minutes per level; flag walls, shrinking requirements and total time. Enable the addon in Project Settings → Plugins and use **Plan XP curve** in the **XP Curve** dock.

Input: `{"xp_to_next": [100, 150, ...], "xp_per_minute": [{"from_level": 1, "rate": 50}, {"from_level": 4, "rate": 80}]}`. `xp_to_next[i]` is the XP from level i+1 to i+2. Instead of a table you can give `"formula": "100 * pow(level, 1.5)", "max_level": 50` (Godot `Expression` syntax, variable `level`). The report lists minutes per level and cumulative hours.

| Finding | Meaning |
|---|---|
| `level_wall` | A level takes more than `--wall-factor` times as long as the previous one. |
| `xp_not_increasing` | A level needs less XP than the one before. |
| `no_rate` | No positive earn-rate band covers a level. |

## Command line

```sh
godot --headless --path . --script res://addons/xp_curve/cli/xpc_cli.gd -- \
  --input=res://demo/balance/xp.json --fail-on=level_wall
```

Options: `--input=<path>` (default `res://demo/balance/xp.json`), `--out=<dir>` (default `res://reports/xp_curve`), `--wall-factor` (a level taking this many times longer than the previous one is a wall (default 2.0)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `xp_curve.json` and `xp_curve.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Earn rate is one number per band; real rates vary with play style, rested XP and content. Use your telemetry averages.
- A designed jump (a new zone, a prestige level) will be flagged; that is the point - confirm it is intended.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
