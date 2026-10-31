# Typed GDScript Coverage Meter

Measure how much GDScript is statically typed (variables, parameters, returns) and gate on a minimum. Enable the addon in Project Settings → Plugins and use **Measure type coverage** in the **Type Coverage** dock.

It reads every `.gd` file under the folder (hidden folders, `addons/` and report folders skipped) and counts declarations: `var`/`const` (typed with `: T`, inferred with `:=`; constants count as typed), each function parameter, and each function return type (`_init` excluded). The report lists per-file percentages and every untyped spot with its line.

| Finding | Meaning |
|---|---|
| `below_threshold` | A file's typed share is below `--min-percent`. |
| `project_below_threshold` | The project-wide share is below `--min-percent`. |

## Command line

```sh
godot --headless --path . --script res://addons/type_coverage/cli/tcm_cli.gd -- \
  --dir=res://demo/code_health --min-percent=90 --fail-on=project_below_threshold
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/type_coverage`), `--min-percent` (minimum typed percentage per file and for the project (default 0 = report only)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `type_coverage.json` and `type_coverage.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Line-based reading: multi-line function signatures and lambdas are not counted; `for` loop variables are not counted.
- `:=` counts as typed even where Godot infers `Variant`.
- With the default `--min-percent=0` it only reports; ratchet the minimum up in CI as coverage improves.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
