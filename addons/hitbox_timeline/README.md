# Hitbox and Hurtbox Timeline Viewer

Build per-animation timelines of when hitbox and hurtbox shapes are active from animation tracks, and flag windows left open or too short for physics to see. Enable the addon in Project Settings → Plugins and use **Build hitbox timelines** in the **Hitbox Timeline** dock.

It parses `Animation` resources (in scenes and `.tres` files) under the folder (hidden folders, `addons/` and report folders skipped) and finds value tracks on `<node>:disabled` (CollisionShape2D/3D) or `<node>:monitoring` / `:monitorable` (Area2D/3D). Each track becomes a list of active windows in seconds and physics frames (`--physics-fps`). Nodes whose path contains `--hurt-pattern` (default `hurt`) are hurtboxes: their off windows are invulnerability.

| Finding | Meaning |
|---|---|
| `stays_active` | A hitbox is still active when the animation ends. |
| `window_too_short` | An active window shorter than one physics frame. |
| `invulnerable_window` | A hurtbox is switched off for a while (review it). |

## Command line

```sh
godot --headless --path . --script res://addons/hitbox_timeline/cli/hht_cli.gd -- \
  --dir=res://demo/runtime_perf --fail-on=stays_active
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/hitbox_timeline`), `--physics-fps` (physics tick rate for frame counts (default 60)), `--hurt-pattern` (node path text marking hurtboxes (default hurt)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `hitbox_timeline.json` and `hitbox_timeline.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Only animation-driven toggles are seen; shapes enabled from code or method tracks are not.
- Overlap between attacker and defender shapes is not computed (no positions); this is a timing view.
- Animation blending and speed scale change real timing.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
