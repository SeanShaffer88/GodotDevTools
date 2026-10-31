# SARIF Exporter

Convert every tool report in a folder into one SARIF 2.1.0 log for code-scanning views. Enable the addon in Project Settings → Plugins and use **Build SARIF summary** in the **SARIF Export** dock.

It reads every `<tool>/<tool>.json` report under `--reports` (default `res://reports`) and writes one SARIF 2.1.0 log, `gdt.sarif`, next to its own report: one run per tool, one rule per finding kind, one result per finding (`error` → error, `warning` → warning, `info` → note; message plus fix; location when the path is a `res://` file, with its line). Upload it with your CI's SARIF/code-scanning step to see findings on pull requests.

| Finding | Meaning |
|---|---|
| `skipped_report` | A report is malformed and was left out. |

## Command line

```sh
godot --headless --path . --script res://addons/sarif_export/cli/srf_cli.gd -- \
  --reports=res://demo/suite/after --fail-on=skipped_report
```

Options: `--reports=<path>` (default `res://reports`), `--out=<dir>` (default `res://reports/sarif_export`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `sarif_export.json` and `sarif_export.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Locations are relative to the project root (`uriBaseId` PROJECTROOT); set the base in your upload step if the project is not at the repository root.
- Findings without a `res://` path have no location; code-scanning views list them without file annotations.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
