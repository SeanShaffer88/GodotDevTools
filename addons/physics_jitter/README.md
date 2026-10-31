# Physics Jitter and Tunneling Detector

Find small rigid bodies without continuous collision detection, scripts that move rigid bodies directly, character movement in _process, and low physics tick rates. Enable the addon in Project Settings → Plugins and use **Detect physics risks** in the **Physics Jitter** dock.

It reads scenes and scripts under the folder (hidden folders, `addons/` and report folders skipped) and the physics settings of `--project`:

- **Tunneling**: a `RigidBody2D`/`RigidBody3D` with `continuous_cd` off whose collision shape is smaller than `--min-size` (circle/sphere/capsule radius, half the smallest box/rectangle side; Godot's default shape sizes when not stored).
- **Transform fights**: a script extending a RigidBody that assigns `position`, `rotation` or `transform` (including `global_*` and `+=`) outside `_integrate_forces`.
- **Physics in _process**: a CharacterBody script calling `move_and_slide()` from `_process`.
- **Low tick rate**: `physics_ticks_per_second` below 60.

| Finding | Meaning |
|---|---|
| `tunneling_risk` | Small rigid body without continuous collision detection. |
| `transform_fight` | Rigid body transform set directly. |
| `physics_in_process` | Character movement in `_process`. |
| `low_tick_rate` | Physics tick rate below 60 Hz. |

## Command line

```sh
godot --headless --path . --script res://addons/physics_jitter/cli/pjt_cli.gd -- \
  --dir=res://demo/runtime_perf --project=res://demo/runtime_perf/physics_project.godot --fail-on=tunneling_risk
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/physics_jitter`), `--project` (project file for physics settings (default res://project.godot)), `--min-size` (shapes smaller than this (radius or half-extent) count as small (default 4)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `physics_jitter.json` and `physics_jitter.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Body speed is unknown statically; small slow bodies are flagged too. Prioritize projectiles and fast movers.
- Shapes assigned from code and inherited scripts are not followed.
- Units differ (pixels in 2D, metres in 3D); set `--min-size` for your scale.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
