# JUnit Exporter

Convert every tool report in a folder into one JUnit XML file so CI test views show tool findings as failures. Enable the addon in Project Settings → Plugins and use **Build JUnit summary** in the **JUnit Export** dock.

It reads every `<tool>/<tool>.json` under `--reports` (default `res://reports`) and writes `gdt-junit.xml`: one `<testsuite>` per tool, one `<testcase>` per finding kind that has findings at or above `--fail-level` (default `warning`), with every finding listed in the failure body, and a passing `clean` case for tools with none. Point your CI's JUnit test-report step at it.

| Finding | Meaning |
|---|---|
| `skipped_report` | A report is malformed and was left out. |

## Command line

```sh
godot --headless --path . --script res://addons/junit_export/cli/jux_cli.gd -- \
  --reports=res://demo/suite/after --fail-on=skipped_report
```

Options: `--reports=<path>` (default `res://reports`), `--out=<dir>` (default `res://reports/junit_export`), `--fail-level` (lowest severity that counts as a failure: error, warning or info (default warning)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `junit_export.json` and `junit_export.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Findings become failures by severity only; use each tool's `--fail-on` for gating and this file for display.
- Durations are not recorded (tools do not report them).
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
