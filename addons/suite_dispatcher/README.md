# Suite CLI Dispatcher

One entry point that lists every installed tool CLI and runs any of them by name, passing options through and returning its exit code. Enable the addon in Project Settings → Plugins and use **List tools** in the **Suite Tools** dock.

Commands:

```sh
godot --headless --path . --script res://addons/suite_dispatcher/cli/gdt_cli.gd -- list
godot --headless --path . --script res://addons/suite_dispatcher/cli/gdt_cli.gd -- run node_paths --fail-on=broken_path
godot --headless --path . --script res://addons/suite_dispatcher/cli/gdt_cli.gd -- all
```

`list` prints every installed tool (addon folders with `plugin.cfg` and `cli/*_cli.gd`). `run <tool>` accepts a folder name or a unique prefix, runs that CLI in a child Godot process with the remaining options, prints its output and exits with its exit code. `all` runs every CLI with its defaults and exits 2 if any exited 2 (1 if any exited 1). Tools never depend on the dispatcher; it only calls their CLIs.

| Finding | Meaning |
|---|---|
| `missing_cli` | An addon folder has no headless CLI to dispatch. |

## Command line

```sh
godot --headless --path . --script res://addons/suite_dispatcher/cli/gdt_cli.gd -- \
  run node_paths --dir=res://demo/code_health --fail-on=broken_path
```

Options: `--addons=<path>` (default `res://addons`), `--out=<dir>` (default `res://reports/suite_dispatcher`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `suite_dispatcher.json` and `suite_dispatcher.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Each run starts a child Godot process, so `all` takes as long as every CLI together.
- `all` uses each tool's defaults, which point at this repo's demo fixtures for many data-driven tools; pass options with `run` for your own project.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
