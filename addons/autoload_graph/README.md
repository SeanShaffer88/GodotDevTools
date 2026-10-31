# Autoload Dependency Graph

Map which autoloads reference which, flag reference cycles, missing scripts and early references to autoloads declared later. Enable the addon in Project Settings → Plugins and use **Map autoloads** in the **Autoload Graph** dock.

It reads the `[autoload]` section of the project file (declaration order is load order), opens each autoload's script (or the root script of an autoload scene) and records every mention of another autoload's name, with the function it appears in. The report lists the load order and the reference graph.

| Finding | Meaning |
|---|---|
| `init_order` | An autoload uses another autoload declared later from `_init`, `_enter_tree` or `_ready`, when the later one may not be in the tree yet. |
| `autoload_cycle` | Autoloads reference each other in a loop (reported once per cycle). |
| `missing_autoload` | An autoload entry points at a file that does not exist. |

## Command line

```sh
godot --headless --path . --script res://addons/autoload_graph/cli/alg_cli.gd -- \
  --project=res://demo/autoloads/autoloads.godot --fail-on=init_order
```

Options: `--project=<path>` (default `res://project.godot`), `--out=<dir>` (default `res://reports/autoload_graph`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `autoload_graph.json` and `autoload_graph.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Name matching: a local variable that shares an autoload's name counts as a reference.
- Only the autoload's own script is read, not scripts it loads or inherits.
- Cycles are not errors in Godot; they are reported as information because they make load-order bugs likely.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
