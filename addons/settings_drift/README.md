# Project Settings Drift Report

Compare project.godot with a committed baseline, key by key, and report added, removed and changed settings. Enable the addon in Project Settings → Plugins and use **Compare with baseline** in the **Settings Drift** dock.

It parses the project file and a baseline copy (Godot ConfigFile text, multi-line values supported), flattens both to `section/key` pairs and compares values as text. Make a baseline by copying an approved `project.godot` to `project_baseline.godot` and committing it. In the dock the baseline is `res://project_baseline.godot`.

| Finding | Meaning |
|---|---|
| `setting_changed` | A key exists in both with different values. |
| `setting_added` | A key exists only in the project file. |
| `setting_removed` | A key exists only in the baseline. |

## Command line

```sh
godot --headless --path . --script res://addons/settings_drift/cli/psd_cli.gd -- \
  --project=res://demo/settings_drift/current.cfg --baseline=res://demo/settings_drift/baseline.cfg --fail-on=setting_changed
```

Options: `--project=<path>` (default `res://project.godot`), `--out=<dir>` (default `res://reports/settings_drift`), `--baseline` (baseline file (default res://project_baseline.godot)), `--ignore` (comma-separated key prefixes to ignore, e.g. editor_plugins/,autoload/), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `settings_drift.json` and `settings_drift.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Values compare as text, so reformatting a value counts as a change.
- Comments are ignored; `config_version` and every other key are compared unless ignored with `--ignore`.
- Use `--ignore=editor_plugins/` (for example) for settings expected to churn.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
