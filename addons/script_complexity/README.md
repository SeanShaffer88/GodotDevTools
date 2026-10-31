# Script Complexity Reporter

Per-function branch complexity, length and nesting depth for GDScript, with thresholds. Enable the addon in Project Settings → Plugins and use **Measure complexity** in the **Script Complexity** dock.

It reads every `.gd` file under the folder (hidden folders, `addons/` and report folders skipped), splits it into functions by indentation and measures each one: **complexity** = 1 + each `if`/`elif`/`for`/`while`, `and`/`or`/`&&`/`||`, inline `x if c else y`, and each `match` arm; **lines** = non-blank, non-comment body lines; **nesting** = deepest block level inside the body.

| Finding | Meaning |
|---|---|
| `complex_function` | Complexity above `--max-complexity` (default 12). |
| `long_function` | Body longer than `--max-lines` (default 60). |
| `deep_nesting` | Nesting deeper than `--max-nesting` (default 4). |

## Command line

```sh
godot --headless --path . --script res://addons/script_complexity/cli/scx_cli.gd -- \
  --dir=res://demo/code_health --fail-on=complex_function,deep_nesting
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/script_complexity`), `--max-complexity` (branch complexity limit (default 12)), `--max-lines` (function length limit in code lines (default 60)), `--max-nesting` (nesting depth limit (default 4)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `script_complexity.json` and `script_complexity.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Indentation- and pattern-based, not a parser; inner lambdas count toward their enclosing function.
- Default limits are conventional starting points, not standards; tune them per team.
- Keywords inside string literals that contain `#` may be counted.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
