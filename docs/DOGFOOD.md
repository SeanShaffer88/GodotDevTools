# Dogfooding on real games

The four-scanner dogfood harness has passed on two pinned public Godot projects, in addition to the synthetic fixtures and large synthetic benchmark in `docs/performance.md`. These are small external smoke tests, **not** validation on a shipped, production-scale game or a measured false-positive rate.

## Method and safety

```sh
sh tests/dogfood/run_dogfood.sh /path/to/godot /path/to/trusted-project /path/to/new-output
python3 tests/dogfood/dogfood.py /path/to/new-output
```

The harness copies the project into a temporary directory, installs the suite there, imports it and runs naming, accessibility-options, duplicate-code and script-complexity scanners. It does not intentionally write into the source project. Reports, command logs and per-process timings go to a new directory outside the source (by default, a unique directory under this repository's `reports/dogfood/`); an existing output is refused and an explicit output's parent must exist.

**This is not a sandbox.** Godot imports and plugins may execute project code, which can access or modify files outside the copy. Run only trusted projects. Python 3 is required; each launched Godot process is limited to 180 seconds by default (`GDT_DOGFOOD_TIMEOUT` overrides this). The watchdog kills the direct process on timeout, not necessarily any children it spawned.

The summary lists import and scanner process elapsed times, exit codes, timeout flags, report summaries, finding kinds and up to three samples per report. It also shows timing files for failed processes without reports. A CLI finding is not automatically a defect or a false positive: the dogfood run is a smoke test and does not pass `--fail-on`. Review findings manually before taking action. The complete JSON/Markdown reports and logs are CI artifacts.

## CI evidence

[Real-project dogfood run 42957927997](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/42957927997) passed both jobs on 2026-11-11, with Godot 4.5 and the scanner version at commit `18469bc`. The [merge-commit run](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/42958408003) also passed. Both run the same pinned projects:

| Project | Scope | Observations from run 42957927997, **before** the sidecar fix |
|---|---|---|
| [Brackeys first game](https://github.com/Brackeys/first-game-in-godot/tree/388257461dbd07b1e5020270c72fca48b30c493d) | Small tutorial game, Godot 4.2 project | Naming: 24 findings / 60 entries; accessibility: no evidence for 7 expected options; duplicate code: 0 findings / 5 files; complexity: 0 findings / 5 files. |
| [Godot platformer starter](https://github.com/deanblackborough/godot-platformer/tree/5ce74ba7e3ffcd2e9339ebbca763b0a32bab1cf5) | Independent work-in-progress platformer, Godot 4.4 project | Naming: 106 findings / 108 entries (20 directories, 86 files); accessibility: no evidence for 7 options; duplicate code: 3 findings / 18 files. See the CI artifact for the complete complexity report. |

The naming counts above include generated sidecar metadata and must not be used as post-fix counts. CI used the default lowercase snake-case convention, which the platformer is not required to adopt. A successful run means the tools completed and produced reports; it does not mean their findings have all been adjudicated. This repo's `demo/` remains a synthetic test baseline, not another real game.

## Sample review and sidecar fix

Review of the pinned source and CI samples confirmed that Brackeys' `PixelOperator8-Bold.ttf.import` is Godot import metadata whose `[deps]` points to the separately scanned `.ttf`. The platformer's `Core/Combat/HitBox.gd.uid` is a UID sidecar for `HitBox.gd`. Treating either metadata filename as an independent naming violation is misleading; the original source asset still needs checking. The audit now skips compound `.import` and `.uid` sidecar names, including orphaned sidecars, but not directories or files with only one extension. See `docs/false_positives.md` and the naming addon's README for the trade-off.

The platformer's `Core` directory really does differ from the default lowercase pattern; whether to change it is a project policy decision. Its three sampled duplicate-code findings correspond to repeated normalized source blocks, but duplication alone does not establish a bug or a worthwhile refactor. Brackeys' reported lack of text-size/UI-scale evidence is consistent with the inspected project scripts and scenes; a text search does not prove an option is absent or unusable. These are spot checks, not full adjudication.

As a separate local check on the pinned **unimported** archives, the standalone Python naming scan changed from 19 to 2 findings on Brackeys and from 106 to 68 on the platformer. All removed paths had `.import` or `.uid` suffixes; no new paths were flagged. This is not a comparison of Godot CI reports: importing adds generated files, and the Python subset is not the engine CLI. Fresh Godot CI reports are needed for post-fix counts.

## Timing interpretation

`elapsed_ms` is monotonic wall time for launching and waiting for a Godot process; it includes startup and scheduling, not just scanner work. The watchdog now uses a blocking wait instead of Python's timed `subprocess` polling loop. A local Linux/Python 3.11.2 sanity check alternated eight runs of a Python child sleeping 60 ms: the old timer reported 114 ms on every run, versus 68–73 ms with the blocking wait. This small experiment demonstrates polling overhead, **not** Godot scanner speed or a controlled performance benchmark. Compare future runs on the same machine and project and use repeated, scanner-only measurements for performance claims.

The earlier `a11y_options` 4.4-second synthetic-project result and subsequent pattern-compilation/cache work are described in `docs/performance.md` and `addons/a11y_options/README.md`. The revised implementation has not been benchmarked on a production-scale real project.
