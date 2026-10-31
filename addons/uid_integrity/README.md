# Resource UID Integrity Checker

Check uid:// references in scenes, resources and scripts against the UIDs files declare. Enable the addon in Project Settings → Plugins and use **Check UIDs** in the **UID Integrity** dock.

It reads every `.tscn`, `.tres`, `.import`, `.uid` and `.gd` file under the folder (hidden folders, `addons/` and report folders skipped). Declared UIDs come from text scene/resource headers, `uid=` in `.import` files and Godot 4.4+ `.uid` sidecars. Each `[ext_resource ... uid="..." path="..."]` is compared with what its path declares, and literal `uid://` strings in scripts must match some declared UID.

| Finding | Meaning |
|---|---|
| `uid_mismatch` | An ext_resource carries a UID that differs from the one its target declares (Godot falls back to the path with a warning). |
| `duplicate_uid` | Two files declare the same UID. |
| `unknown_uid` | A referenced UID matches no scanned file. |

## Command line

```sh
godot --headless --path . --script res://addons/uid_integrity/cli/uid_cli.gd -- \
  --dir=res://demo/uids --fail-on=uid_mismatch
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/uid_integrity`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `uid_integrity.json` and `uid_integrity.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Scan the whole project (`--dir=res://`) for reliable `unknown_uid` results; a partial scan cannot see targets elsewhere.
- Binary `.scn`/`.res` files are not read.
- It does not rewrite references; re-saving in the editor fixes most mismatches.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
