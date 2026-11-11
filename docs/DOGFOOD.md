# Dogfooding on real games

All gate evidence so far is on the synthetic `demo/` fixture and a synthetic 4,623-file project (`docs/performance.md`). This page tracks real-world runs.

## Method

`tests/dogfood/run_dogfood.sh <godot-binary> <project-dir> [new-output-dir]` copies the project into a temporary directory, installs the suite there, imports it and runs four scanners. The harness does not write into the source project. Reports and command logs go to a new directory outside the source project (by default, a unique directory under this repository's `reports/dogfood/`); an existing output directory is refused, and an explicit output's parent must already exist. `tests/dogfood/dogfood.py <reports-dir>` prints report summaries. False-positive review and timing aggregation are still manual. Only run trusted projects: Godot's import may execute their code and plugins, which can themselves access files outside the copy.

## Candidate real projects (open-source Godot games)

| Project | Why | Status |
|---|---|---|
| Godot demos (godotengine/godot-demos) | Real, maintained, varied genres | Pending first run |
| Open-source Godot 4 games on GitHub (search: `godot 4 game`) | Real-world messiness | Pending first run |
| This repo's own `demo/` (baseline) | Synthetic control | Used by existing tests; dogfood run pending |

## False positives

Every dogfood finding that is wrong gets an entry in `docs/false_positives.md` with tool, file, why it is wrong, and whether it was fixed or suppressed via `addons/suppressions`. The goal is a published false-positive rate per tool, not just a finding count.

## Performance

`a11y_options` was the slowest scanner (4.4s on the synthetic project). It now compiles each pattern once, searches whole files, and supports per-file incremental caching (`--cache=<file>`). Changing expectations invalidates the cache. See `addons/a11y_options/README.md`; the revised implementation has not yet been benchmarked on a real project.
