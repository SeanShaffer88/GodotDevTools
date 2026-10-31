# Export Variable Range Auditor

Check @export_range limits against script defaults and the values scenes store, and list numeric exports with no range hint. Enable the addon in Project Settings → Plugins and use **Audit export ranges** in the **Export Ranges** dock.

It reads `@export_range(min, max, ...)` declarations from every `.gd` file under the folder (hidden folders, `addons/` and report folders skipped), checks each declaration's literal default, and then checks every value a `.tscn` stores for that property on a node whose script is the declaring script. `or_greater` and `or_less` lift the matching limit, as in the inspector.

| Finding | Meaning |
|---|---|
| `out_of_range` | A scene stores a value outside the declared range. |
| `default_out_of_range` | The script's own default is outside its range. |
| `no_range_hint` | Only with `--report-unhinted`: an `@export var x: int/float` has no range. |

## Command line

```sh
godot --headless --path . --script res://addons/export_ranges/cli/era_cli.gd -- \
  --dir=res://demo/export_ranges --fail-on=out_of_range
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/export_ranges`), `--report-unhinted` (also list numeric @export vars with no range hint), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `export_ranges.json` and `export_ranges.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Only single-line declarations with literal numeric limits are read; ranges built from constants are skipped.
- Inherited scripts and values set on instanced child scenes from the parent scene are not followed.
- Values set from code at runtime are not checked.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
