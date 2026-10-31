# Scene Load Smoke Tester

Load and instantiate every scene headless; report scenes that fail to load or instantiate, missing dependencies and node types that no longer exist. Enable the addon in Project Settings → Plugins and use **Smoke test scenes** in the **Scene Smoke Test** dock.

For every `.tscn`/`.scn` under the folder (hidden folders, `addons/` and report folders skipped) it checks the dependencies Godot lists for the scene, loads it (bypassing the resource cache), compares each node type in the scene state with the engine's classes and global script classes, instantiates it and frees it. Scenes are never added to the tree, so `_ready` and `_process` do not run; script `_init` does.

| Finding | Meaning |
|---|---|
| `load_failed` | The scene did not load (parse errors). |
| `instantiate_failed` | Loaded, but `instantiate()` returned null. |
| `missing_dependency` | A referenced file does not exist. |
| `unknown_type` | A node type the running Godot does not have (Godot replaces it with a placeholder). |

## Command line

```sh
godot --headless --path . --script res://addons/scene_smoke/cli/sst_cli.gd -- \
  --dir=res://demo/ci/smoke --fail-on=unknown_type
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/scene_smoke`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `scene_smoke.json` and `scene_smoke.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Runs scene scripts' `_init`; scenes whose constructors have side effects (file writes, network) will perform them. Run on a disposable checkout if unsure.
- Errors only visible in `_ready` or later are not caught; add an opt-in play test for those.
- Engine error messages still print to the output; the findings are the summary.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
