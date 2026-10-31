# Node Path Breakage Detector

Check $Path, get_node() and %Unique references in scripts against the scenes the scripts are attached to. Enable the addon in Project Settings → Plugins and use **Check node paths** in the **Node Paths** dock.

It scans every `.tscn` and `.gd` under the folder (hidden folders, `addons/` and report folders skipped). For each scene node with a script, every literal path in that script is resolved from that node: `$Child/Grandchild`, `$"Name With Spaces"`, `get_node("...")`, `get_node_or_null("...")` and `%UniqueName` (a node marked `unique_name_in_owner`). Paths that pass through an instanced child scene continue inside that scene's text.

| Finding | Meaning |
|---|---|
| `broken_path` | A literal path resolves in none of the scenes that attach the script. |
| `missing_unique` | A `%Name` reference has no `unique_name_in_owner` node of that name in any owning scene. |
| `unattached_script` | Only with `--report-unattached`: a script uses node paths but no scanned scene attaches it. |

## Command line

```sh
godot --headless --path . --script res://addons/node_paths/cli/npb_cli.gd -- \
  --dir=res://demo/code_health --fail-on=broken_path
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/node_paths`), `--report-unattached` (report scripts that use paths but are attached to no scanned scene), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `node_paths.json` and `node_paths.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Nodes added from code (`add_child`) at runtime are invisible; such findings are false positives to ignore.
- Absolute paths (`/root/...`) and paths assembled from variables are skipped and counted as `dynamic_skipped`.
- Scripts attached through inheritance or set from code are not linked to scenes.
- Pattern-based reading of GDScript, not a parser; unusual formatting may be missed.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
