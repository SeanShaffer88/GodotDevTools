# Resource Load Failure Simulator

Find runtime load() calls whose result is used without a null check, chained load().instantiate() calls, missing literal paths and threaded loads without a status check. Enable the addon in Project Settings → Plugins and use **Find fragile loads** in the **Load Failures** dock.

It reads every `.gd` file under the folder (hidden folders, `addons/` and report folders skipped) and, for each runtime load, follows what happens when it returns null: `load(...)` chained straight into a call; a variable assigned from `load()`/`ResourceLoader.load()`/`load_threaded_get()` and then used (`x.method()`) before any `if`/`assert`/`is_instance_valid`/`== null` check in the same block; `load_threaded_get()` in a script that never calls `load_threaded_get_status()`; and literal `res://` paths that do not exist. `preload()` is checked by the GDScript compiler and skipped.

| Finding | Meaning |
|---|---|
| `unchecked_load` | A loaded value is used before a null check. |
| `chained_load` | `load(...).something()` with no chance to check. |
| `missing_resource` | A literal load path does not exist. |
| `threaded_no_status` | Threaded load fetched without a status check. |

## Command line

```sh
godot --headless --path . --script res://addons/load_failure/cli/rlf_cli.gd -- \
  --dir=res://demo/testing/loads --fail-on=unchecked_load,missing_resource
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/load_failure`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `load_failure.json` and `load_failure.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Static, pattern-based reading; loads wrapped in helper functions are not followed.
- Paths built at runtime are not checked for existence (use the Project Cleanup Workbench and export tests).
- It does not inject real load failures at runtime.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
