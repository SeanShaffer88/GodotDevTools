# Log Warning Budget Gate

Gate a captured Godot log on error and warning counts and on signatures not present in a committed baseline. Enable the addon in Project Settings → Plugins and use **Check log budget** in the **Log Budget** dock.

It counts lines with Godot's error and warning prefixes in `--log`, groups them by masked signature (single-quoted names become `'<str>'`, numbers `N`), and compares with `--baseline`:

```json
{"errors": 0, "warnings": 3, "signatures": ["WARNING: Texture '<str>' is larger than N px."]}
```

The JSON report's `suggested_baseline` holds this run's counts and signatures; commit it once you have reviewed the log.

| Finding | Meaning |
|---|---|
| `error_budget` | More error lines than the baseline allows. |
| `warning_budget` | More warning lines than the baseline allows. |
| `new_signature` | A message signature the baseline has never seen. |

## Command line

```sh
godot --headless --path . --script res://addons/log_budget/cli/lbg_cli.gd -- \
  --log=res://demo/ci/logs/run.log --baseline=res://demo/ci/logs/baseline.json --fail-on=error_budget
```

Options: `--log=<path>` (default `res://demo/ci/logs/run.log`), `--out=<dir>` (default `res://reports/log_budget`), `--baseline` (baseline JSON {errors, warnings, signatures} (default res://log_baseline.json)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `log_budget.json` and `log_budget.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Counts are lines, so one problem repeating per frame counts many times; fix the cause or capture a fixed-length run.
- The baseline is a ratchet: raising it should be a reviewed change.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
