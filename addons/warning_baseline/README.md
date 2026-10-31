# GDScript Warning Baseline

Count common GDScript warning patterns per file (unused variables and parameters, unreachable code) and ratchet them against a baseline. Enable the addon in Project Settings → Plugins and use **Compare warnings** in the **Warning Baseline** dock.

Godot does not print GDScript warnings in headless runs, so the tool detects three common warning patterns itself, named after Godot's warning codes:

- `UNUSED_VARIABLE` - a local `var` never mentioned again in its function;
- `UNUSED_PARAMETER` - a parameter not mentioned in the body and not prefixed with `_`;
- `UNREACHABLE_CODE` - a statement after `return`, `break` or `continue` in the same block.

Counts are kept per file and code. With `--baseline`, any count above the baseline fails; the JSON report's `suggested_baseline` holds this run's counts to commit after review.

| Finding | Meaning |
|---|---|
| `warning_increase` | A file has more of a warning code than the baseline. |
| `new_warning_file` | A file the baseline does not list has warnings. |

## Command line

```sh
godot --headless --path . --script res://addons/warning_baseline/cli/gwb_cli.gd -- \
  --dir=res://demo/ci/warnings --baseline=res://demo/ci/warnings/baseline.json --fail-on=warning_increase
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/warning_baseline`), `--baseline` (baseline JSON {file: {CODE: count}}; empty = report counts only), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `warning_baseline.json` and `warning_baseline.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Approximations of Godot's analyzer by name matching: a variable mentioned only in a string still counts as used, and the editor may report cases this misses.
- Other Godot warnings (shadowing, narrowing conversion, integer division...) are not detected; the editor's own warnings remain the reference.
- The baseline may only go down; raising it should be a reviewed change.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
