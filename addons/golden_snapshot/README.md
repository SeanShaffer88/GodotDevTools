# Golden Data Snapshot Tester

Compare JSON outputs with approved golden files and report differences by JSON path, with a float tolerance. Enable the addon in Project Settings → Plugins and use **Compare with goldens** in the **Golden Snapshots** dock.

Files are paired by relative path between `--current` (this run's outputs) and `--golden` (approved copies, default `res://tests/golden`). Each pair is parsed as JSON and walked together; every difference is reported with its JSON path, such as `$.enemies[2].hp`. Numbers within `--tolerance` match. Up to 50 differences are listed per file.

| Finding | Meaning |
|---|---|
| `changed_value` | A value differs. |
| `added_key` | A key or array element exists only in the output. |
| `removed_key` | A key or array element exists only in the golden. |
| `type_changed` | A value changed type. |
| `missing_golden` | An output has no golden yet. |
| `missing_output` | A golden has no output from this run. |
| `bad_json` | One side is not valid JSON. |

## Command line

```sh
godot --headless --path . --script res://addons/golden_snapshot/cli/gst_cli.gd -- \
  --current=res://demo/ci/golden/actual --golden=res://demo/ci/golden/expected --fail-on=changed_value
```

Options: `--current=<path>` (default `res://demo/ci/golden/actual`), `--out=<dir>` (default `res://reports/golden_snapshot`), `--golden` (folder of approved golden JSON files (default res://tests/golden)), `--tolerance` (absolute tolerance for numbers (default 0.000001)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `golden_snapshot.json` and `golden_snapshot.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Array elements compare by position: an insertion early in an array reports every later element.
- Approving a change is a manual copy of the output over the golden; the tool never writes goldens.
- JSON only; produce JSON from your systems under test (saves, generated levels, balance tables).
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
