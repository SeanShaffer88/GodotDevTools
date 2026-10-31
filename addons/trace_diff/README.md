# State Trace Determinism Diff

Compare two recorded per-frame state traces and report the first frame and keys where they diverge. Enable the addon in Project Settings → Plugins and use **Diff traces** in the **Trace Diff** dock.

Record the same session twice (same seed, same inputs) and save each as `{"frames": [{"frame": 0, "state": {"x": 1.5, "player": {"hp": 10}}}]}`. Frames are matched by number; state keys are compared with one level of nesting flattened (`player.hp`). The report gives the first divergent frame and its differing keys, and how many compared frames differ. It complements the Deterministic Seed and Replay Runner, which checks PRNG and event chains rather than state.

| Finding | Meaning |
|---|---|
| `divergence` | The traces differ; the message names the first frame and keys. |
| `length_mismatch` | The traces have different frame counts. |
| `bad_trace` | A trace is missing or not in the trace format (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/trace_diff/cli/sdt_cli.gd -- \
  --first=res://demo/ci/traces/run_a.json --second=res://demo/ci/traces/run_b.json --fail-on=divergence
```

Options: `--first=<path>` (default `res://demo/ci/traces/run_a.json`), `--out=<dir>` (default `res://reports/trace_diff`), `--second` (second trace JSON), `--tolerance` (absolute tolerance for numbers (default 0)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `trace_diff.json` and `trace_diff.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Only state you record is compared; record the variables that matter (positions, RNG state, health).
- Deeper nesting than one level is compared as whole values.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
