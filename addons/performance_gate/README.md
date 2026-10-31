# Performance Regression Gate

Compare benchmark measurements against reviewed baselines. Enable the plugin and provide two JSON paths in the dock, or run:

```sh
godot --headless --path . --script res://addons/performance_gate/cli/perf_cli.gd -- \
  --baseline=res://demo/performance/baseline.json --current=res://demo/performance/current.json \
  --fail-on=regression,missing_metric
```

Baseline example:

```json
{"metrics":{"frame_ms":{"value":16,"unit":"ms","direction":"higher_is_worse","tolerance_pct":5,"tolerance_abs":0.5}}}
```

Current example: `{"metrics":{"frame_ms":{"value":20,"unit":"ms"}}}`. Directions are `higher_is_worse` or `lower_is_worse`. Tolerances are non-negative and default to zero. The allowed change is the **larger** of the absolute tolerance and `abs(baseline) × tolerance_pct / 100`. A worsening strictly greater than the allowance is a regression; improvements and changes exactly at the boundary pass. Units must match exactly. A zero baseline is handled by the absolute allowance. Missing and unbaselined metrics are reported separately; they are not silently compared.

The CLI defaults to the demo fixtures and writes JSON and Markdown under `res://reports/performance_gate` (`--out` overrides). `--fail-on` accepts `regression`, `missing_metric`, `unbaselined_metric`, or `issues`; a selected finding exits 2. Invalid input, baseline or measurement, mismatched units, or report-write failures exit 1. Errors take precedence over warning gates. Otherwise exit 0.

This tool **does not run benchmarks or measure variance**. Supply measurements captured using a consistent benchmark, hardware, build configuration and workload, and choose tolerances based on observed noise. It compares one scalar value per metric, not distributions, confidence intervals or automatic hardware normalization. The tool never edits measurements and uses no network. Godot execution and a hands-on editor session remain to be verified.
