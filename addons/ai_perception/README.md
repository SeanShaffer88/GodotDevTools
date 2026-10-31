# AI Perception Debugger

Evaluate sight and hearing for AI agents in a 2D scenario with walls, trace every decision, and check expected outcomes. Enable the addon in Project Settings → Plugins and use **Evaluate perception** in the **AI Perception** dock.

Input:

```json
{"walls": [[300, -100, 300, 100]],
 "agents": [{"id": "guard", "pos": [0, 0], "facing_deg": 0, "fov_deg": 90, "sight_range": 500, "hearing_range": 250}],
 "targets": [{"id": "player", "pos": [400, 0], "noise": 1.0}],
 "expect": [{"agent": "guard", "target": "player", "sees": false}]}
```

For every agent-target pair it decides sight (within `sight_range`, within half of `fov_deg` of the facing, no wall segment crossing the line) and hearing (within `hearing_range × noise × wall_muffle^walls`), records the numbers behind each decision in the report's `trace`, and checks the `expect` entries.

| Finding | Meaning |
|---|---|
| `expectation_failed` | A sees/hears outcome differs from the expectation (the message includes the reasons). |
| `unknown_reference` | An expectation names an unknown agent or target. |

## Command line

```sh
godot --headless --path . --script res://addons/ai_perception/cli/aip_cli.gd -- \
  --input=res://demo/gameplay/perception.json --fail-on=expectation_failed
```

Options: `--input=<path>` (default `res://demo/gameplay/perception.json`), `--out=<dir>` (default `res://reports/ai_perception`), `--wall-muffle` (hearing range multiplier per wall between listener and source (default 0.5)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `ai_perception.json` and `ai_perception.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- A 2D model of common perception rules; your game's AI code is not executed. Keep the scenario's numbers in sync with your agents.
- Walls are segments; agent and target sizes, partial cover and memory/alertness states are not modelled.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
