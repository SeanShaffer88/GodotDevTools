# Gameplay Scenario Test Builder

Write repeatable gameplay scenarios as JSON steps (wait, press/release actions, call methods, set properties, assert values) and run them headless. Enable the addon in Project Settings → Plugins and use **Validate scenario** in the **Scenario Tests** dock.

Scenario:

```json
{"scene": "res://levels/arena.tscn", "steps": [
  {"action": "jump", "press": true}, {"frames": 6}, {"action": "jump", "press": false},
  {"assert": {"node": "Player", "property": "velocity", "op": "!=", "value": 0}},
  {"call": {"node": ".", "method": "add", "args": [10]}},
  {"set": {"node": "Player", "property": "health", "value": 1}},
  {"assert": {"node": ".", "property": "count", "op": ">=", "value": 15}}]}
```

The CLI instances the scene under a runner node and executes one step per physics frame (`frames` waits that many physics frames); node paths are relative to the scene root (`.` is the root). Assertion ops: `==`, `!=`, `<`, `<=`, `>`, `>=`, `approx` (±0.001), `contains`. Actions still held at the end are released. The dock validates scenario files; running needs the CLI. Use the runner node in your own test scenes for custom setups.

| Finding | Meaning |
|---|---|
| `assertion_failed` | An assertion did not hold (actual value in the message). |
| `step_error` | A step referenced a missing node or the scene failed to load. |
| `bad_scenario` | The scenario file is malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/scenario_tests/cli/gsb_cli.gd -- \
  --scenario=res://demo/testing/scenario/hold_and_add.json --fail-on=assertion_failed
```

Options: `--scenario=<path>` (default `res://demo/testing/scenario/hold_and_add.json`), `--out=<dir>` (default `res://reports/scenario_tests`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `scenario_tests.json` and `scenario_tests.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Runs in the headless process: rendering-dependent behaviour (viewports, shaders, GPU particles) is not exercised.
- Physics frames run as fast as the machine allows; timing-sensitive logic using wall-clock time behaves differently.
- A step that crashes the engine ends the run without a report.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
