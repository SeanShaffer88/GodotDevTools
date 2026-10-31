# Feature Flag and Rollout Simulator

Simulate flag combinations offline with a synthetic subject identifier. Enable the addon and run the dock, or use:

```sh
godot --headless --path . --script res://addons/flag_simulator/cli/flag_cli.gd -- \
  --config=res://demo/flags/clean.json --subject=demo-subject
```

Input example: `{"flags":{"core":{"default":true,"rollout":100},"shop":{"default":false,"rollout":50,"requires":["core"]}}}`. Each flag requires a boolean `default`, a rollout percentage from 0 to 100 (default 0), and an optional array of named prerequisites. A flag is enabled only when its candidate decision and every prerequisite are enabled. Unknown prerequisites, invalid definitions and cycles are errors; no decisions are reported for an invalid graph.

With configuration available, the candidate is determined by a stable flag-and-subject bucket in `[0, 9999]`; percentages are rounded to 0.01 percentage points. With `--unavailable`, candidates use configured local defaults, while prerequisites remain enforced. The result includes each candidate, final decision, bucket, source and prerequisite status.

The CLI writes JSON and Markdown under `res://reports/flag_simulator` (`--out` overrides). `--fail-on=errors` or `--fail-on=invalid_flag,unknown_prerequisite,prerequisite_cycle` returns 2 for matching validation findings; invalid input or report-write failure returns 1; otherwise exit 0. Defaults use the deliberately broken demo configuration; use `clean.json` for a passing example.

The local bucketing algorithm is a simple deterministic 10,000-bucket hash, **not cryptographic**, not privacy-preserving, and not guaranteed to match a production flag provider. Do not use real player identifiers. This simulator does not connect to services, fetch remote configuration, write flag settings, simulate segment targeting, or provide a runtime feature flag SDK. Godot execution and a hands-on editor session remain to be verified.
