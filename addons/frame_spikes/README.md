# Frame-Time Spike Investigator

Find frame-time spikes in a recorded frame log and correlate each with markers, node-count jumps and physics time; includes a runtime recorder. Enable the addon in Project Settings → Plugins and use **Investigate spikes** in the **Frame Spikes** dock.

Record a log in game with `runtime/fts_recorder.gd` (add it as an autoload, call `mark("load_level")` around suspect work, then `save_log()`), or write the same JSON from your own logger:

```json
{"fps_target": 60, "frames": [{"frame": 0, "ms": 16.1, "physics_ms": 2.0, "nodes": 850, "markers": []}]}
```

A spike is a frame slower than both the budget (1000 / fps_target) and the median × `--spike-factor`. For each spike, `--window` frames around it are searched for markers and node-count jumps of 100 or more, and the physics share of the frame is checked; these are listed as likely causes.

| Finding | Meaning |
|---|---|
| `frame_spike` | A spike frame, with likely causes. |
| `budget_miss_rate` | More than `--max-miss-rate` of frames exceed the budget: sustained load. |

## Command line

```sh
godot --headless --path . --script res://addons/frame_spikes/cli/fts_cli.gd -- \
  --input=res://demo/runtime_perf/frames.json --fail-on=frame_spike
```

Options: `--input=<path>` (default `res://demo/runtime_perf/frames.json`), `--out=<dir>` (default `res://reports/frame_spikes`), `--spike-factor` (a frame slower than median x this is a spike (default 1.5)), `--window` (frames before and after a spike searched for causes (default 2)), `--max-miss-rate` (share of frames allowed over the frame budget (default 0.05)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `frame_spikes.json` and `frame_spikes.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Correlation, not proof: a marker near a spike is a lead to profile, not a diagnosis.
- Performance monitors are sampled once per frame; GPU time is not included.
- The recorder is unit-tested; a live game session is pending.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
