# Demo-to-Release Content Guard

Review development content before a release. Enable the addon in Project Settings → Plugins and use **Scan development markers**. The dock scans text files under `res://` for the case-sensitive markers `DEBUG_MENU`, `PLACEHOLDER` and `TEST_ONLY`, reporting paths and line numbers. Findings are candidates for human review, not proof a file is included in an export.

```sh
godot --headless --path . --script res://addons/release_guard/cli/rg_cli.gd -- \
  --dir=res://demo/release_guard --fail-on=placeholder
```

The CLI writes `release_guard.json` and `release_guard.md` under `res://reports/release_guard` (override with `--out=<dir>`). Use `--fail-on=debug_marker,placeholder,test_content`, `--fail-on=issues` or `--fail-on=errors` to return 2 when matching findings exist. Unreadable scans, invalid rule files and report-write failures return 1. Otherwise it exits 0.

For project-specific conventions, pass `--rules=res://path/to/rules.json`. The file must be a JSON array of objects with a nonempty string `marker`; optional `kind` and `severity` default to `marker` and `warning`. Custom rules replace the defaults. Example:

```json
[{"marker":"TODO_RELEASE", "kind":"release_todo", "severity":"warning"}]
```

The scanner only reads supported text formats (GDScript, C#, text scenes/resources, text, JSON, CFG, INI, CSV and PO), skips hidden directories, `addons`, and report directories, and searches literal text—including comments and strings. It does not inspect binary assets, evaluate code, determine which files an export includes, or automatically identify unmarked placeholders and debug menus. Configure rules and review findings before shipping. It never modifies assets. Godot execution and hands-on editor verification are pending.
