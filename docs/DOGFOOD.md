# Dogfooding on real games

All gate evidence so far is on the synthetic `demo/` fixture and a synthetic 4,623-file project (`docs/performance.md`). This page tracks real-world runs.

## Method

`tests/dogfood/run_dogfood.sh <godot-binary> <project-dir> [new-output-dir]` copies the project into a temporary directory, installs the suite there, imports it and runs four scanners. The harness does not write into the source project. Reports, command logs and per-process elapsed times go to a new directory outside the source project (by default, a unique directory under this repository's `reports/dogfood/`); an existing output directory is refused, and an explicit output's parent must already exist. Python 3 is required; commands time out after 180 seconds by default (`GDT_DOGFOOD_TIMEOUT` overrides this). `tests/dogfood/dogfood.py <reports-dir>` prints summaries, finding kinds and a few samples. Elapsed times include process startup and are not controlled benchmarks. False-positive review remains manual. Only run trusted projects: Godot's import may execute their code and plugins, which can themselves access files outside the copy.

## Candidate real projects (open-source Godot games)

| Project | Why | Status |
|---|---|---|
| [Brackeys first game](https://github.com/Brackeys/first-game-in-godot/tree/388257461dbd07b1e5020270c72fca48b30c493d) | Small tutorial game, Godot 4.2 project | CI run pending |
| [Godot platformer starter](https://github.com/deanblackborough/godot-platformer/tree/5ce74ba7e3ffcd2e9339ebbca763b0a32bab1cf5) | Independent work-in-progress platformer, Godot 4.4 project | CI run pending |
| This repo's own `demo/` (baseline) | Synthetic control | Used by existing tests; dogfood run pending |

`.github/workflows/dogfood.yml` runs the four scanners with Godot 4.5 on pinned commits of the two public projects in disposable copies. It attaches reports/logs and emits finding counts and elapsed times. A tutorial and a starter are useful external smoke tests, not substitutes for dogfooding a shipped, production-scale game.

## False positives

Every dogfood finding that is wrong gets an entry in `docs/false_positives.md` with tool, file, why it is wrong, and whether it was fixed or suppressed via `addons/suppressions`. The goal is a published false-positive rate per tool, not just a finding count.

## Performance

`a11y_options` was the slowest scanner (4.4s on the synthetic project). It now compiles each pattern once, searches whole files, and supports per-file incremental caching (`--cache=<file>`). Changing expectations invalidates the cache. See `addons/a11y_options/README.md`; the revised implementation has not yet been benchmarked on a real project.
