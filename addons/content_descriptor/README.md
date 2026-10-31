# Content Descriptor Checklist

Track your own content questionnaire: unanswered questions, answers outside the allowed options, missing evidence and stale reviews. Enable the addon in Project Settings → Plugins and use **Check questionnaire** in the **Content Descriptors** dock.

Input:

```json
{"questions": [{"id": "violence", "text": "Depictions of violence", "options": ["none", "fantasy", "realistic"], "evidence_required": true}],
 "answers": {"violence": {"value": "fantasy", "evidence": "res://levels/arena.tscn", "reviewer": "QA", "date": "2026-10-01"}}}
```

Write the questions yourself from the questionnaires your rating bodies and stores use. The tool checks that every question is answered with an allowed option, that questions marked `evidence_required` point at an existing file or folder, and that no answer is older than `--max-age-days` (measured from `--today` or the system date).

| Finding | Meaning |
|---|---|
| `unanswered` | A question has no answer. |
| `invalid_answer` | An answer is not one of the question's options. |
| `missing_evidence` | Evidence is required but missing or not found. |
| `stale_answer` | The answer is older than `--max-age-days`. |

## Command line

```sh
godot --headless --path . --script res://addons/content_descriptor/cli/cdc_cli.gd -- \
  --input=res://demo/shipping/descriptors.json --today=2026-10-31 --fail-on=unanswered
```

Options: `--input=<path>` (default `res://demo/shipping/descriptors.json`), `--out=<dir>` (default `res://reports/content_descriptor`), `--max-age-days` (answers older than this are stale (default 365)), `--today` (date to measure age from, YYYY-MM-DD (default: system date)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `content_descriptor.json` and `content_descriptor.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Bookkeeping only: it never assigns or predicts a rating, and makes no claim about any rating body's rules.
- Evidence is checked for existence, not reviewed.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
