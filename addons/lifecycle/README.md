# Pause, Focus, and Lifecycle Tester

Work out which scripted nodes keep running while the game is paused, catch pause menus that freeze themselves, and flag missing focus/suspend handling and wall-clock timers. Enable the addon in Project Settings → Plugins and use **Check pause and lifecycle** in the **Lifecycle** dock.

It reads scripts and scenes under the folder (hidden folders, `addons/` and report folders skipped). Each scene node's effective `process_mode` is resolved by Godot's rules (Inherit follows the parent; a scene root inherits Pausable) to decide what runs while the tree is paused. For nodes whose script has `_process`/`_physics_process`/input callbacks: a pause UI (its script assigns `paused =`, or its name contains "pause") that does not run while paused is an error, and other nodes that do run while paused are noted. It also reports a project that pauses but never handles focus loss/app suspension, and scripts timing gameplay with `Time.get_ticks_msec()`/`get_ticks_usec()`/`get_unix_time_from_system()`.

| Finding | Meaning |
|---|---|
| `pause_menu_frozen` | The pause UI stops processing when paused, so it cannot unpause. |
| `keeps_running_when_paused` | A scripted node keeps running while paused. |
| `no_focus_pause` | The game pauses but never reacts to focus loss or suspension. |
| `wallclock_timing` | Wall-clock timing ignores pause. |

## Command line

```sh
godot --headless --path . --script res://addons/lifecycle/cli/pfl_cli.gd -- \
  --dir=res://demo/lifecycle --fail-on=pause_menu_frozen
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/lifecycle`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `lifecycle.json` and `lifecycle.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Static resolution: process modes changed from code and instanced sub-scenes' inner nodes are not followed.
- Audio, Timers and Tweens follow process mode too; only scripted nodes are reported.
- It does not run the game; verify suspend/resume on the device.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
