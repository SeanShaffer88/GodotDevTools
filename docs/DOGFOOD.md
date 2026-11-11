# Dogfooding on real games

All gate evidence so far is on the synthetic `demo/` fixture and a synthetic 4,623-file project (`docs/performance.md`). This page tracks real-world runs.

## Method

`tests/dogfood/run_dogfood.sh <godot-binary> <project-dir>` copies the addons into a real Godot project, runs a scanner subset, and writes `reports/dogfood/dogfood.json` (per-tool findings + timing). `tests/dogfood/dogfood.py` aggregates runs and appends false positives to `docs/false_positives.md`.

## Candidate real projects (open-source Godot games)

| Project | Why | Status |
|---|---|---|
| Godot demos (godotengine/godot-demos) | Real, maintained, varied genres | Pending first run |
| Open-source Godot 4 games on GitHub (search: `godot 4 game`) | Real-world messiness | Pending first run |
| This repo's own `demo/` (baseline) | Synthetic control | Verified in CI |

## False positives

Every dogfood finding that is wrong gets an entry in `docs/false_positives.md` with tool, file, why it is wrong, and whether it was fixed or suppressed via `addons/suppressions`. The goal is a published false-positive rate per tool, not just a finding count.

## Performance

`a11y_options` was the slowest scanner (4.4s on the synthetic project). It now compiles one combined regex per option and searches whole files instead of per-line lambdas, and supports incremental caching (`--cache=<file>`): unchanged files (by content hash) are skipped on rescans. See `addons/a11y_options/README.md`. Re-benchmark with `tests/bench/` after the first dogfood run.
