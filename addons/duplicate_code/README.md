# Duplicate Code Detector

Find repeated blocks of GDScript across files after normalizing whitespace and comments. Enable the addon in Project Settings → Plugins and use **Find duplicate code** in the **Duplicate Code** dock.

It reads every `.gd` file under the folder (hidden folders, `addons/` and report folders skipped), normalizes each line (trimmed, comments and blank lines dropped, repeated spaces collapsed), and finds every run of at least `--min-lines` normalized lines (default 6) that appears in more than one place, including twice in one file. Overlapping matches merge into the longest common block. Windows made only of `pass`/`else:`/`return` are ignored.

| Finding | Meaning |
|---|---|
| `duplicate_block` | A block of normalized lines repeats; the finding lists every place. |

## Command line

```sh
godot --headless --path . --script res://addons/duplicate_code/cli/dup_cli.gd -- \
  --dir=res://demo/code_health --fail-on=duplicate_block
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/duplicate_code`), `--min-lines` (smallest block to report, in normalized lines (default 6)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `duplicate_code.json` and `duplicate_code.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Exact clones only: renamed variables or reordered lines are not matched.
- Groups are matched per identical starting window; three-way clones whose extents differ are reported at the shortest common extent.
- Some duplication is intentional (tests, generated code); treat findings as refactoring suggestions.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
