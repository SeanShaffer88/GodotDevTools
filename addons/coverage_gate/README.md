# Coverage Gate

Estimate GDScript coverage from test evidence and gate CI on a minimum percent. Enable the addon, enter a folder, and select **Estimate coverage**.

```sh
godot --headless --path . --script res://addons/coverage_gate/cli/cvg_cli.gd -- --dir=res://addons --min-percent=50 --fail-on=below_threshold
```

Options: `--dir=<path>`, `--tests=<dir>` (default `res://tests`), `--min-percent=<float>`, `--out=<dir>`, `--fail-on=below_threshold`. Exits 2 on `--fail-on`, 1 on bad input/write failure, 0 otherwise.

## Scope and limitations

- **Estimate, not measurement.** Godot has no built-in line coverage. A function counts as covered when a test file mentions its name or its file stem. The report sets `estimate: true`.
- Trend tracking lives in `tools/coverage/` (`coverage_trend.py` appends to `docs/coverage_trend.csv`); mutation trending is in `tools/coverage/mutation_trend.py`.
- Use the number comparatively (is it going up?) rather than as an absolute quality claim.
