# Report Diff

Compare two report folders and list new, fixed and unchanged findings, matching findings even when their line moved. Enable the addon in Project Settings → Plugins and use **Diff reports** in the **Report Diff** dock.

Run the tools on the base branch and on your change, keep both `reports/` folders, then compare: `--before` (base) and `--after` (change). Findings are matched by tool, kind, path and message with numbers masked, so a finding whose line moved is unchanged. Gate pull requests with `--fail-on=new_finding`; existing debt does not block, new debt does.

| Finding | Meaning |
|---|---|
| `new_finding` | A finding present after but not before. |
| `fixed_finding` | A finding present before but not after. |

## Command line

```sh
godot --headless --path . --script res://addons/report_diff/cli/rdf_cli.gd -- \
  --before=res://demo/suite/before --after=res://demo/suite/after --fail-on=new_finding
```

Options: `--before=<path>` (default `res://demo/suite/before`), `--out=<dir>` (default `res://reports/report_diff`), `--after` (reports folder from the later run), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `report_diff.json` and `report_diff.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- A changed message wording counts as fixed + new.
- Malformed reports are ignored; validate them with the Report Schema tool.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
