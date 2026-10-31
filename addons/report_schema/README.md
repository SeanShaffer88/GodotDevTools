# Report Schema

The documented JSON shape every tool report follows, and a validator that checks report folders against it. Enable the addon in Project Settings → Plugins and use **Validate reports** in the **Report Schema** dock.

Every tool in this repo writes `reports/<tool>/<tool>.json` with:

```json
{"summary": {"issues": 1},
 "issues": [{"severity": "warning", "kind": "broken_path", "path": "res://player.gd", "line": 16,
             "message": "...", "fix": "..."}]}
```

`severity` (`error`, `warning` or `info`), `kind` and `message` are required; `path`, `line` (1-based, 0 when not applicable) and `fix` are usual. The CLI writes the JSON Schema (draft 2020-12) as `report.schema.json` next to its report and validates every `<tool>/<tool>.json` under `--reports` (default `res://reports`).

| Finding | Meaning |
|---|---|
| `schema_violation` | A report breaks the contract (details in the message). |
| `not_a_report` | A JSON file without a summary (tools such as Scene Search write results, not findings). |

## Command line

```sh
godot --headless --path . --script res://addons/report_schema/cli/rsv_cli.gd -- \
  --reports=res://demo/suite/after --fail-on=schema_violation
```

Options: `--reports=<path>` (default `res://reports`), `--out=<dir>` (default `res://reports/report_schema`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `report_schema.json` and `report_schema.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- The validator checks the required contract directly; it is not a general JSON Schema engine.
- Tool-specific extra fields are allowed and not validated.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
