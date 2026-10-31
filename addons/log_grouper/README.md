# Error Log Grouper

Group Godot error and warning lines from a captured log by normalized signature and count them. Enable the addon in Project Settings → Plugins and use **Group log messages** in the **Log Grouper** dock.

Capture Godot's output (for example `godot --headless ... 2>&1 | tee run.log`) and pass it with `--log`. Lines starting with `ERROR:`, `SCRIPT ERROR:`, `USER ERROR:`, `WARNING:` or `USER WARNING:` are grouped by signature: the line with single-quoted names replaced by `'<str>'` and numbers by `N`. Each group lists its count, first line and the following `at:` location.

| Finding | Meaning |
|---|---|
| `error_group` | A group of error lines (count in the message). |
| `warning_group` | A group of warning lines. |

## Command line

```sh
godot --headless --path . --script res://addons/log_grouper/cli/lgr_cli.gd -- \
  --log=res://demo/ci/logs/run.log --fail-on=error_group
```

Options: `--log=<path>` (default `res://demo/ci/logs/run.log`), `--out=<dir>` (default `res://reports/log_grouper`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `log_grouper.json` and `log_grouper.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Signatures mask single-quoted text and numbers only; messages that embed other varying text form separate groups.
- Only Godot's standard prefixes are recognized; `print()` output is ignored.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
