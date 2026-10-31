# Damage Formula Sandbox

Evaluate a damage formula over every combination of stat values and flag negatives, overflows and non-monotonic results. Enable the addon in Project Settings → Plugins and use **Evaluate formula** in the **Damage Formula** dock.

Input:

```json
{"formula": "atk * (100.0 / (100.0 + def)) * mult - armor",
 "vars": {"atk": [10, 50, 200], "def": [0, 50, 400], "mult": [0.5, 1.0, 2.0], "armor": [0, 20]},
 "expect": {"min": 0, "max": 1000, "monotonic": {"atk": "increasing", "def": "decreasing"}}}
```

The formula is parsed with Godot's `Expression` class (the same syntax as GDScript expressions, including built-ins such as `max`, `pow`, `clamp`) and evaluated for every combination of the listed values. The summary reports the result range; findings cite the worst combination.

| Finding | Meaning |
|---|---|
| `negative_result` | Some results fall below `expect.min`. |
| `overflow` | Some results exceed `expect.max`. |
| `non_monotonic` | The result moves the wrong way as a stat in `expect.monotonic` grows. |
| `eval_error` | The formula does not parse, or a combination produces an error or a non-finite value. |

## Command line

```sh
godot --headless --path . --script res://addons/damage_sandbox/cli/dfs_cli.gd -- \
  --input=res://demo/balance/damage.json --fail-on=negative_result
```

Options: `--input=<path>` (default `res://demo/balance/damage.json`), `--out=<dir>` (default `res://reports/damage_sandbox`), `--max-combinations` (evaluation cap (default 100000)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `damage_sandbox.json` and `damage_sandbox.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Only the listed sample values are tested; choose them to cover the edges (zero, caps, extremes).
- Use float literals (`100.0`) where integer division would change the result, as in GDScript.
- The formula runs through `Expression` with no base object; treat formula files like code you trust.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
