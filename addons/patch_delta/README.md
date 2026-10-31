# Patch Delta Estimator

Compare two staged builds file by file (size and MD5) and estimate the bytes a patch must ship. Enable the addon in Project Settings → Plugins and use **Estimate patch** in the **Patch Delta** dock.

Point `--old` and `--new` at two staged build folders (the exported files as players receive them). Files are paired by relative path and compared by MD5. The estimated patch is the bytes of added files plus the full size of changed files; removed files are listed. A changed `.pck` is called out because one asset change re-ships the whole pack.

| Finding | Meaning |
|---|---|
| `delta_budget` | Estimated patch bytes exceed `--max-delta`. |
| `monolithic_pack` | A `.pck` changed and ships whole. |

## Command line

```sh
godot --headless --path . --script res://addons/patch_delta/cli/pde_cli.gd -- \
  --old=res://demo/shipping/builds/v1 --new=res://demo/shipping/builds/v2 --max-delta=10000 --fail-on=delta_budget
```

Options: `--old=<path>` (default `res://demo/shipping/builds/v1`), `--out=<dir>` (default `res://reports/patch_delta`), `--new` (folder of the new staged build), `--max-delta` (patch byte budget (default 0 = report only)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `patch_delta.json` and `patch_delta.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- File-level estimate: stores and launchers with chunk or binary diffing ship less; ones that re-download everything ship more.
- Contents inside `.pck` and archives are not attributed (pair with the Build Size Attribution Explorer).
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
