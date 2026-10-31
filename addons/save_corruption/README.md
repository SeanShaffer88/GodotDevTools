# Save Corruption and Recovery Tester

Feed systematically corrupted versions of a sample save to your loader and check it falls back safely instead of accepting bad data. Enable the addon in Project Settings → Plugins and use **Corrupt and load** in the **Save Corruption** dock.

Your loader script needs a static `load_save(text: String) -> Variant` and, ideally, a static `is_valid(save: Dictionary) -> bool`. From `--save` (a known-good JSON save) the tool builds corrupted variants: truncated, empty, not JSON, array/null root, an unexpected extra key, every top-level key given a value of another type, every key removed, and all numbers set to huge negative or huge positive values. Each variant goes through `load_save`; the result must be a Dictionary (null is allowed only with `--allow-null`) that your `is_valid` accepts.

| Finding | Meaning |
|---|---|
| `accepted_invalid` | The loader returned data its own validator rejects. |
| `no_fallback` | The loader returned null or errored. |
| `bad_return` | The loader returned something other than a Dictionary. |

## Command line

```sh
godot --headless --path . --script res://addons/save_corruption/cli/scr_cli.gd -- \
  --save=res://demo/testing/saves/sample.json --loader=res://demo/testing/saves/naive_loader.gd --fail-on=accepted_invalid
```

Options: `--save=<path>` (default `res://demo/testing/saves/sample.json`), `--out=<dir>` (default `res://reports/save_corruption`), `--loader` (script with static load_save(text) -> Variant and optional static is_valid(save) -> bool), `--allow-null` (treat returning null as a safe rejection (default false: the loader must return a fallback Dictionary)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `save_corruption.json` and `save_corruption.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- JSON saves only; binary `store_var` saves need a JSON-based test harness first.
- The loader runs in this process; a loader that crashes the engine ends the run.
- Validation quality is only as good as your `is_valid`.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
