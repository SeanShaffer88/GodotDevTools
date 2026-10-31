# Loot Table and Economy Simulator

Simulate weighted loot tables with a fixed seed: drop odds, expected value per open, observed rates and worst-case droughts. Enable the addon in Project Settings → Plugins and use **Simulate loot** in the **Loot Simulator** dock.

Input format:

```json
{"tables": {"chest": {"rolls": 1, "entries": [
  {"item": "gold", "weight": 70, "value": 5},
  {"item": "dragon_blade", "weight": 0.2, "value": 5000}]}}}
```

For each table it reports per-roll and per-open odds (`1 - (1 - p)^rolls`), the expected `value` per open, the 99th-percentile drought (opens before a 1-in-100 unlucky player sees the item), and a seeded simulation of `--draws` opens with observed rates and the longest drought seen.

| Finding | Meaning |
|---|---|
| `drought_risk` | An item's 99th-percentile drought exceeds `--max-drought` opens. |
| `zero_weight` | An entry has weight 0 or less and can never drop. |
| `empty_table` | A table has no droppable entries or fewer than one roll. |

## Command line

```sh
godot --headless --path . --script res://addons/loot_sim/cli/lts_cli.gd -- \
  --input=res://demo/balance/loot.json --fail-on=drought_risk
```

Options: `--input=<path>` (default `res://demo/balance/loot.json`), `--out=<dir>` (default `res://reports/loot_sim`), `--draws` (simulated opens per table (default 10000)), `--seed` (random seed (default 1)), `--max-drought` (flag items whose 99th-percentile drought exceeds this many opens (default 200)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `loot_sim.json` and `loot_sim.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Rolls are independent with replacement; tables that remove an item once dropped, or nested tables, are not modelled.
- Pity systems are not simulated; use the drought numbers to choose a pity threshold.
- `value` is whatever unit you supply; no economy inflation or sinks are modelled.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
