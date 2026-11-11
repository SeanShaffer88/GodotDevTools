# GodotDevTools - Quality Scorecard

The expanded suite passed its Linux Godot 4.3/4.4/4.5/4.6 gates and editor/live-game session on commit `d430a6c` in [CI](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/42955115939), and the Windows 4.3 gate and sessions passed in [CI](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/42955115937). Versions 4.4/4.6 remain experimental. The specific editor interaction checks passed Linux and Windows on `b77e785`; see `docs/DOCK_A11Y.md`. Hosted CI does not establish hands-on hardware-GPU support.

The forty-suite gate previously passed headless CI on Godot 4.3 and 4.5 on main (run 41168830957). The check-count breakdown and scorecard below describe the earlier twenty-nine-suite baseline, not a comprehensive assessment of the new additions.

Gate: `sh tests/run_tests.sh <godot-binary>` - **292/292 test checks passed, 0 failed** across the twenty-nine suites (VRT 16, GSTM 12, RUIP 8, AHD 10, DQD 22, MNS 12, NLSS 9, A11Y 8, BED 7, DBP 8, SMG 9, CMV 8, PAR 9, AUD 8, MLH 7, IMX 9, SHD 9, SGS 10, LMX 10, BTD 10, COR 12, SDR 10, WBX 10, VFM 11, TMR 8, CTR 11, THM 11, PFG 8, DCG 10), plus every CLI smoke and exit-code-2 gate assertion in the same run. The gate runs automatically in CI (`.github/workflows/tests.yml`) on pushes to main and pull requests, green on both Godot 4.3.stable and 4.5.stable headless (Linux).

| Dimension | Score (1-5) | Evidence |
|---|---|---|
| Correctness | 4 | Per-tool suites pass on a fixture that contains one deliberate case per promised check; every one of the 29 CLIs is exercised by the gate, 25 of them including their exit-code-2 path. |
| Completeness vs brief | 5 | All 110 roadmap entries are implemented and checked. There are 133 addons, each with a core, an editor dock, a headless CLI, a fixture and tests; runtime nodes exist where a tool needs live data. The research entry ends in a recorded decision. |
| Code quality | 4 | One core operation per tool, no editor APIs in cores, docks/CLIs are thin shells; deterministic seeds where randomness exists. |
| Tests | 4 | Fixture-driven suites per tool plus CLI smoke and exit-code gates in one `run_tests.sh`. No coverage tooling for GDScript; suites assert behaviour, not lines. |
| UX / plain language | 4 | Every dock control has a tooltip and an offline `?` help text, and every finding carries a plain-words fix. All 133 docks pass a real-editor session. It is not a 5 because hands-on Windows use is still owed. |
| Safety / privacy | 5 (historical) | The original tools run offline and require explicit approval for writes. New opt-in Fix Engine and Suite Presets actions can modify project files; review their limitations and backups before applying. Some tools execute project code. |
| Performance | 4 | All 39 project-wide scanners ran on a synthetic 4,623-file project in 20.8 s total: median 147 ms, worst 4.4 s (docs/performance.md). The two quadratic hotspots that run found are fixed. Real-project and Windows timing are still Unverified. |

A green gate is evidence for its tested cases, not proof of complete correctness or device compatibility. Unreleased additions and limitations are tracked in CHANGELOG.md and README.md.

## CI coverage and historical baseline

There are 138 addons, each with its own test suite. All 110 roadmap entries are checked; see ROADMAP.md for what a check requires. CI runs three kinds of evidence on every PR:

- **Gate** (`sh tests/run_tests.sh`, on Godot 4.3 and 4.5, plus experimental 4.4 and 4.6): per-tool suites, CLI smoke tests and exit-code gates, plus the dock smoke suite. It constructs the 138 docks, checks interactive controls' tooltips and focus, and exercises their run actions where supported outside the editor.
- **Real-editor session** (`tests/editor/run_editor_session.sh`, Godot 4.3, Xvfb, Mesa llvmpipe):
  - the windowed editor loads every plugin;
  - a test plugin brings each dock to the front, clicks its run button with real mouse events, and checks that output appears;
  - it takes a screenshot of each dock;
  - for Macro Recorder, it opens a scene, clicks Preview, and records an Inspector edit.
  The expanded 138-dock session passed in CI; specific interactions are tracked separately in `docs/DOCK_A11Y.md`.
- **Live-game session** (`tests/game/run_live_game.sh`): the 16 runtime nodes run in a windowed game with real frames, physics and input events, for 19 checks. A further check confirms that the subtitle layout measure matches a rendered Label. All 20 checks pass.
  - The live session found a real defect: `seed_replay`'s `randi_range`/`randf_range` called the engine's unseeded global `randf()`, so seeded replays diverged. It is fixed and covered by a regression test.

## Verification status

- Verified in the historical baseline:
  - the pre-expansion core operations, CLI reports and CI gates on Godot 4.3-stable and 4.5-stable (Linux);
  - the 133 pre-expansion editor docks in a real editor session;
  - the existing runtime nodes in a live game session.
  The expanded suite and Windows workflow have since passed CI as linked above. The Linux sessions use software OpenGL; the clicks are synthetic mouse events delivered through the editor's viewport.
- Partially Verified:
  - The capture, painted dialogue graph, responsive-preview, and local-position snapping interaction checks passed in windowed CI for their fixtures; see `docs/DOCK_A11Y.md` for scope and limitations.
  - Estimator outputs are estimates, not measurements: thermal_sim device constants, batch_profiler draw calls, and Asset Health's per-platform GPU texture memory. Their comparative use is tested; real-device truth is not claimable here.
- Unverified: hands-on use on Windows with a hardware GPU, production-project dogfooding and performance, and other Godot versions/platforms beyond the tested CI matrix. See `docs/WINDOWS_GPU.md` and `docs/DOGFOOD.md`.
