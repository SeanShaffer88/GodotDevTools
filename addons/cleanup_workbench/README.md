# Project Cleanup Workbench

Collect cleanup candidates for review: unreferenced assets, duplicate files, stale .import and .uid sidecars, empty folders. Never deletes. Enable the addon in Project Settings → Plugins and use **Collect cleanup candidates** in the **Cleanup Workbench** dock.

For every file under the scanned folder it reports, for review: assets (images, audio, models, fonts, scenes, resources) whose `res://` path or UID appears in no text file under `--root` (default `res://`: scripts, scenes, resources, project and export settings, JSON, CSV, docs); groups of files with identical MD5; `.import`/`.uid` sidecars whose source is gone; and empty folders. Hidden folders and report folders are skipped.

| Finding | Meaning |
|---|---|
| `unused_candidate` | No reference found. |
| `duplicate_file` | Byte-identical to another file. |
| `stale_import` | An .import whose source is gone. |
| `orphan_uid` | A .uid whose source is gone. |
| `empty_folder` | An empty folder. |

## Command line

```sh
godot --headless --path . --script res://addons/cleanup_workbench/cli/pcw_cli.gd -- \
  --dir=res://demo/workflow/cleanup --fail-on=stale_import
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/cleanup_workbench`), `--root` (folder whose text files count as references (default res://)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `cleanup_workbench.json` and `cleanup_workbench.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Never deletes: removal is a human step, ideally in a commit of its own.
- Paths built at runtime (`load("res://levels/%s.tscn" % name)`) are invisible; such files appear unused.
- Duplicates are byte-identical only; visually identical re-encodes are not detected.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
