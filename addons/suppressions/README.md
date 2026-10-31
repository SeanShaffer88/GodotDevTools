# Finding Suppression Baseline

Apply a reviewed list of accepted findings, each with a written justification and optional expiry, to a reports folder; gate on what remains. Enable the addon in Project Settings → Plugins and use **Apply suppressions** in the **Suppressions** dock.

Suppression list (default `res://gdt_suppressions.json`):

```json
[{"tool": "asset_health", "kind": "oversized_texture", "path": "res://art/big.png",
  "justification": "Title backdrop, streamed once.", "expires": "2027-06-30"},
 {"tool": "node_paths", "kind": "broken_path", "path": "res://player.gd", "message_contains": "Muzzle",
  "justification": "Added by the weapon at runtime."}]
```

`tool`, `kind` and a non-empty `justification` are required; `path`, `message_contains` and `expires` narrow or limit it. Every finding in the reports folder that no active suppression matches is re-emitted as `unsuppressed_finding` with its original severity, so `--fail-on=errors` or `--fail-on=unsuppressed_finding` gates the whole suite in one step. Reports are never modified.

| Finding | Meaning |
|---|---|
| `unsuppressed_finding` | A finding no active suppression covers (original severity kept). |
| `expired_suppression` | Past its `expires` date; no longer applied. |
| `missing_justification` | No justification; refused. |
| `unused_suppression` | Matches nothing; remove it. |
| `bad_suppressions` | List missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/suppressions/cli/fsb_cli.gd -- \
  --reports=res://demo/suite/after --suppressions=res://demo/suite/suppressions.json --today=2026-10-31 --fail-on=unsuppressed_finding
```

Options: `--reports=<path>` (default `res://reports`), `--out=<dir>` (default `res://reports/suppressions`), `--suppressions` (suppression list JSON (default res://gdt_suppressions.json)), `--today` (date for expiry checks, YYYY-MM-DD (default: system date)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `suppressions.json` and `suppressions.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Matching is exact on tool, kind and path; a renamed file needs its suppression updated.
- Dates compare as YYYY-MM-DD text.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
