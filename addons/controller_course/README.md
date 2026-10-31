# Character Controller Test Course

Check a platformer controller's tuning against a course of ledges, gaps and slopes using projectile kinematics. Enable the addon in Project Settings → Plugins and use **Run the course** in the **Controller Course** dock.

Input:

```json
{"physics_fps": 60,
 "controller": {"gravity": 980, "jump_velocity": 420, "max_speed": 220, "coyote_time": 0.1, "jump_buffer": 0.1, "floor_max_angle_deg": 45},
 "course": [{"id": "wall", "type": "ledge", "height": 128}, {"id": "pit", "type": "gap", "width": 160}, {"id": "ramp", "type": "slope", "angle_deg": 30}]}
```

Use your controller's real numbers (same units as your level: pixels or metres). It computes peak jump height `v² / 2g`, air time `2v / g` and running reach `max_speed × (air time + coyote_time)`, then tests every obstacle. Passable obstacles within `--margin` of the limit are noted as tight.

| Finding | Meaning |
|---|---|
| `unreachable_ledge` | Higher than the jump peak. |
| `unjumpable_gap` | Wider than running reach. |
| `too_steep_slope` | Steeper than floor_max_angle. |
| `tight_margin` | Passable with little headroom. |
| `short_grace_window` | Coyote time or jump buffer under two physics frames. |

## Command line

```sh
godot --headless --path . --script res://addons/controller_course/cli/cct_cli.gd -- \
  --input=res://demo/runtime_perf/controller.json --fail-on=unreachable_ledge
```

Options: `--input=<path>` (default `res://demo/runtime_perf/controller.json`), `--out=<dir>` (default `res://reports/controller_course`), `--margin` (share of headroom below which a passable obstacle is flagged as tight (default 0.1)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `controller_course.json` and `controller_course.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Ideal kinematics: acceleration time, variable-height jumps, air control, apex hang and collision shape size change real reach.
- Course obstacles come from your data, not from level geometry; pair with level playtests.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
