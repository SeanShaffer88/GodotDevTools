# State Transition Coverage Tracker

Compare manually supplied expected and observed state-transition lists. Both JSON inputs have the shape `{"transitions":[{"from":"idle","to":"walk"}]}`. Counts reflect trace records, not runtime instrumentation. Duplicate expected transitions are errors; uncovered and unexpected transitions are warnings. Order and guards are not validated; transitions with identical endpoints are treated as the same edge.

Enable the dock, or run `godot --headless --path . --script res://addons/state_coverage/cli/coverage_cli.gd -- --first=res://demo/state_coverage/model.json --second=res://demo/state_coverage/trace.json --fail-on=uncovered_transition`. `--out` changes the report directory. JSON and Markdown reports are written under `res://reports/state_coverage` by default. Selected warnings or `issues` exit 2; malformed input and I/O errors exit 1; otherwise exit 0. Godot and hands-on editor verification are pending.
