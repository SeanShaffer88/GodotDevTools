# Animation Performance Auditor

Find constant animation tracks, redundant keys, duplicate keys at the same time and animations with too many tracks. Enable the addon in Project Settings → Plugins and use **Audit animations** in the **Animation Audit** dock.

It parses `Animation` resources (sub-resources inside `.tscn` files and standalone `.tres` files) under the folder (hidden folders, `addons/` and report folders skipped). For each value track it compares key values as stored text: all keys equal → constant track; an interior key equal to both neighbours on a nearest/linear track → redundant; two keys at the same time → duplicate. Animations with more than `--max-tracks` tracks are flagged.

| Finding | Meaning |
|---|---|
| `constant_track` | Every key of a value track is the same. |
| `redundant_keys` | Interior keys equal to both neighbours (removable). |
| `duplicate_time_key` | Two keys share a time. |
| `track_budget` | More tracks than `--max-tracks`. |

## Command line

```sh
godot --headless --path . --script res://addons/anim_audit/cli/apa_cli.gd -- \
  --dir=res://demo/perf_static --fail-on=constant_track
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/anim_audit`), `--max-tracks` (tracks per animation (default 64)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `anim_audit.json` and `anim_audit.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Value tracks only; transform/bezier/method/audio tracks and imported animations inside glTF are not inspected.
- Values compare as text, so 1 and 1.0 count as different.
- Cubic interpolation can make an equal-valued key meaningful; only nearest and linear tracks get redundant-key findings.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
