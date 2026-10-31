# Micro-Benchmark Harness

Time every bench_* method of a benchmark script with warm-up and repeated runs; write median/p95 results the Performance Regression Gate can read. Enable the addon in Project Settings → Plugins and use **Run benchmarks** in the **Benchmarks** dock.

Write a script whose benchmark methods are named `bench_*` and take no arguments:

```gdscript
extends RefCounted
func bench_sum_array() -> void:
    var total := 0
    for i in range(2000):
        total += i
```

The harness instantiates it, runs each method `--warmup` times untimed and `--iterations` times timed (`Time.get_ticks_usec`), and reports min, median, p95 and coefficient of variation. The JSON report's `metrics` object is valid `--current` input for the Performance Regression Gate (`unit: us`, `higher_is_worse`); store a reviewed run as its baseline.

| Finding | Meaning |
|---|---|
| `noisy_benchmark` | Spread above `--max-cv`; results are unstable. |
| `no_benchmarks` | No `bench_*` methods (exit 1). |
| `bad_bench_script` | Script missing or not instantiable (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/bench_harness/cli/mbh_cli.gd -- \
  --script=res://demo/ci/bench/bench_math.gd --iterations=5 --warmup=1
```

Options: `--script=<path>` (default `res://demo/ci/bench/bench_math.gd`), `--out=<dir>` (default `res://reports/bench_harness`), `--iterations` (timed runs per method (default 30)), `--warmup` (untimed runs first (default 5)), `--max-cv` (flag spread (coefficient of variation) above this (default 0.5)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `bench_harness.json` and `bench_harness.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Runs your code in the current process; benchmark only code that is safe to run repeatedly.
- Microsecond timer and a shared machine: compare runs on the same machine, and prefer work that takes at least tens of microseconds.
- Engine-level frame timing is out of scope; use the profiler or the Performance Regression Gate with your own frame metrics.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
