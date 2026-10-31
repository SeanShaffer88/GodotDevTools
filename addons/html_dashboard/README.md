# Static HTML Dashboard

Build one self-contained offline HTML page summarizing every tool report in a folder. Enable the addon in Project Settings → Plugins and use **Build dashboard summary** in the **HTML Dashboard** dock.

It reads every `<tool>/<tool>.json` under `--reports` (default `res://reports`) and writes `dashboard.html` next to its own report: one self-contained page (inline CSS and a few lines of inline script, nothing loaded from the network) with per-tool error/warning/info counts, each tool's findings in a collapsible section, and severity filters. It follows the system light/dark setting. Attach it to CI runs as an artifact or open it locally.

| Finding | Meaning |
|---|---|
| `skipped_report` | A report is malformed and was left off the page. |

## Command line

```sh
godot --headless --path . --script res://addons/html_dashboard/cli/hdb_cli.gd -- \
  --reports=res://demo/suite/after --fail-on=skipped_report
```

Options: `--reports=<path>` (default `res://reports`), `--out=<dir>` (default `res://reports/html_dashboard`), `--title` (page title (default GodotDevTools report)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `html_dashboard.json` and `html_dashboard.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- A snapshot of one run; use Report Diff to compare runs.
- Large report sets make a long page; filter or split by tool if needed.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
