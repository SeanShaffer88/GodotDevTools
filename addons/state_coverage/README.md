# State Transition Coverage Tracker

Compare a declared model with recorded transitions. Both JSON inputs have the shape `{"transitions":[{"from":"idle","to":"walk"}]}`. Duplicate model edges are errors; uncovered and unexpected edges are warnings. Transitions with the same endpoints count as one edge; guards and state-machine semantics are not inferred.

## Recording in game

Add `runtime/coverage_node.gd` to a node and explicitly call `record_transition(previous_state, next_state)` whenever your game transitions. This is opt-in: the tool does **not** discover or instrument state machines automatically. `recording = false` pauses collection, `clear()` begins a new session, and `start_sequence()` marks the next valid transition as a new independent sequence. Call `save_trace("user://coverage_trace.json")` explicitly to write the trace; check the returned Godot error code. `snapshot()` returns a detached dictionary without writing anything.

The recorder keeps at most `max_transitions` (default 10,000) and drops the oldest entries when full. Snapshots contain `truncated` and `dropped` metadata; a truncated trace triggers a `truncated_trace` warning because coverage can be incomplete. Invalid state names and buffer sizes are rejected. No player identifiers or event payloads are collected; state names themselves may still be sensitive.

## Audit

Enable the dock, or run:

```sh
godot --headless --path . --script res://addons/state_coverage/cli/coverage_cli.gd -- \
  --first=res://demo/state_coverage/model.json --second=res://demo/state_coverage/trace.json \
  --check-continuity --fail-on=uncovered_transition,trace_discontinuity,truncated_trace
```

Continuity checking is opt-in: adjacent transitions must connect unless the latter has `"reset": true`. Use `start_sequence()` before recording separate runs or independent state machines; otherwise a discontinuity can be expected. Without the flag, existing unordered trace files remain valid. This check is not a full behavioral or guard validator.

`--out` changes the report directory. JSON and Markdown reports are written under `res://reports/state_coverage` by default. Selected warning kinds or `issues` exit 2; malformed input and I/O errors exit 1; otherwise exit 0. The Godot CI gate tests the core and runtime node headlessly; a hands-on editor and real-game session are still owed.
