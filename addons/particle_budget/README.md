# Particle Budget Inspector

Totals how many particles each scene could hold at once and flags emitters that blow a budget. Enable the addon in Project Settings → Plugins, set the scene and emitter budgets in the **Particle Budget** dock, and press **Scan particle budgets**.

The scan reads every `.tscn` under `res://` (skipping hidden folders, `addons/` and report folders) and finds `GPUParticles2D`, `GPUParticles3D`, `CPUParticles2D` and `CPUParticles3D` nodes. It follows instanced child scenes, so a level that instances three campfires counts all three campfires' emitters, each reported with its instance chain (`SparkFx/Burst`).

For each scene it reports:

- **Worst case** - the sum of every emitter's capacity, as if all were active at once.
- **Always on** - the sum for emitters that start emitting and are not `one_shot`.

Capacity is `amount` × `amount_ratio` (GPU emitters; Godot 4.2+), using Godot's defaults (`amount = 8`, `amount_ratio = 1.0`) when the scene omits a property.

| Finding | Default limit | Meaning |
|---|---|---|
| `scene_budget` | 4000 | Scene worst case exceeds the scene budget. |
| `emitter_budget` | 1000 | One emitter's capacity exceeds the emitter budget. |
| `cpu_heavy` | 500 | A CPU emitter simulates many particles on the main thread. |
| `preprocess_cost` | 1.0 s | `preprocess` simulates that much time in a single frame when the emitter enters the tree. |
| `missing_scene` | - | An instanced scene could not be found, so its emitters are not counted. |
| `instance_cycle` | - | The instance chain loops back on itself. |

The default limits are starting points, not platform guidance. Set them from your own profiling on your target hardware.

## Command line

```sh
godot --headless --path . --script res://addons/particle_budget/cli/pbi_cli.gd -- \
  --dir=res://demo/particles --max-scene=3000 --fail-on=scene_budget
```

Options: `--dir=<res path>` (default `res://`), `--out=<dir>` (default `res://reports/particle_budget`), `--max-scene=<n>`, `--max-emitter=<n>`, `--max-cpu-emitter=<n>`, `--max-preprocess=<seconds>`, `--fail-on=<kinds>` (any finding kind above, `issues`, or `errors`). It writes `particle_budget.json` and `particle_budget.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for an unreadable scan directory or scene, an invalid argument, or a report-write failure; otherwise 0.

## Limits

- Static only. A script that changes `amount`, `amount_ratio` or `emitting` at runtime is not seen, and particles spawned from code are not counted.
- Worst case assumes every emitter is active together; it is an upper bound, not a live count. Live counts need a profiler session on the device.
- Sub-emitters (`sub_emitter`) and trails are not followed; binary `.scn` scenes are not read.
- Particle cost depends on the process material, draw passes, overdraw and renderer, none of which this tool measures. Pair it with the batching profiler and on-device profiling.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
