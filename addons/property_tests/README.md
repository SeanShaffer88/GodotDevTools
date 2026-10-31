# Property-Based Gameplay Tester

Generate many seeded inputs for pure GDScript functions, check stated properties, and shrink failures to a minimal counterexample. Enable the addon in Project Settings → Plugins and use **Run property tests** in the **Property Tests** dock.

Spec:

```json
{"script": "res://game/angles.gd", "seed": 7, "runs": 200, "tests": [
  {"function": "wrap_degrees", "args": [{"type": "int", "min": -100000, "max": 100000}], "properties": ["result >= 0", "result < 360"]}]}
```

Functions must be static and pure (no scene needed). Argument generators: `int`/`float` (`min`, `max`), `bool`, `choice` (`values`). Edge values (bounds, 0, -1, 1) are tried first, then seeded random values up to `runs`. Properties are Godot `Expression`s over `result` and `args`. A failing input is shrunk toward zero (or the nearest bound) to a minimal counterexample.

| Finding | Meaning |
|---|---|
| `property_failed` | A property failed; the message gives the minimal counterexample. |
| `bad_spec` | A missing function or an expression that does not parse. |

## Command line

```sh
godot --headless --path . --script res://addons/property_tests/cli/pbt_cli.gd -- \
  --input=res://demo/testing/props/spec.json --fail-on=property_failed
```

Options: `--input=<path>` (default `res://demo/testing/props/spec.json`), `--out=<dir>` (default `res://reports/property_tests`), `--runs` (inputs per function (overrides the spec)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `property_tests.json` and `property_tests.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Static, pure functions only; for scene behaviour use the Gameplay Scenario Test Builder.
- Shrinking is per argument toward zero/bounds; strings, arrays and nested structures are not generated.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
