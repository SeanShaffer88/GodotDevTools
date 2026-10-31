# Startup and Scene-Load Profiler

Time how long each scene takes to load and instantiate in this process, with dependency and node counts, against budgets. Enable the addon in Project Settings → Plugins and use **Profile scene loads** in the **Load Profiler** dock.

For every `.tscn`/`.scn` under the folder (hidden folders, `addons/` and report folders skipped) it loads the scene with the resource cache bypassed for that scene (`CACHE_MODE_IGNORE`), instantiates it, counts its nodes and frees it, timing each step with `Time.get_ticks_usec`. Scenes are reported slowest first with direct dependency counts. Run it on the target machine class; timings from a development machine are optimistic.

| Finding | Meaning |
|---|---|
| `slow_load` | Load time above `--max-load-ms`. |
| `slow_instantiate` | Instantiate time above `--max-instantiate-ms`. |
| `load_failed` | The scene did not load. |

## Command line

```sh
godot --headless --path . --script res://addons/load_profiler/cli/slp_cli.gd -- \
  --dir=res://demo/runtime_perf --max-load-ms=0 --fail-on=slow_load
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/load_profiler`), `--max-load-ms` (load budget per scene (default 500)), `--max-instantiate-ms` (instantiate budget per scene (default 100)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `load_profiler.json` and `load_profiler.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Dependencies loaded by an earlier scene stay cached, so shared costs land on whichever scene loads them first; profile one scene per run for exact figures.
- Runs scripts' `_init`; `_ready` and first-frame costs are not included.
- Exported builds load from `.pck` and may differ from editor/headless timing.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
