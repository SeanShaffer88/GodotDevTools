# Save File Bloat Auditor

Measure JSON save files by key, find keys that dominate the file, and track key growth across ordered sample saves. Enable the addon in Project Settings → Plugins and use **Audit saves** in the **Save Bloat** dock.

Point it at a folder of sample saves exported from real play sessions, named so that file-name order is play order (`save_01.json`, `save_02.json`, ...). For every save it measures each top-level key and each key one level down by the byte size of its compact JSON, then compares the first and last sample per key.

| Finding | Meaning |
|---|---|
| `save_over_budget` | A save file is larger than `--max-bytes`. |
| `key_dominates` | One top-level key takes more than `--dominant-share` of a save. |
| `key_growth` | A key grew by `--growth-factor` or more from the first to the last sample (and is over 256 bytes). |

## Command line

```sh
godot --headless --path . --script res://addons/save_bloat/cli/sba_cli.gd -- \
  --dir=res://demo/balance/saves --fail-on=key_growth
```

Options: `--dir=<path>` (default `res://demo/balance/saves`), `--out=<dir>` (default `res://reports/save_bloat`), `--max-bytes` (total save size budget (default 1048576)), `--dominant-share` (share of a save one key may take (default 0.5)), `--growth-factor` (growth from first to last sample that is flagged (default 4)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `save_bloat.json` and `save_bloat.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- JSON object saves only; `store_var`, `var_to_str` and encrypted saves are not read - export a JSON debug copy for auditing.
- Sizes are compact JSON bytes, not on-disk bytes after your own compression.
- Growth compares only the first and last samples; supply samples from short and long sessions.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
