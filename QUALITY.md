# GodotDevTools - Quality Scorecard

The forty-suite gate passed headless CI on Godot 4.3 and 4.5 on main (run 41168830957); suites added after that run are listed in CHANGELOG.md and gated by the same `run_tests.sh`. Editor docks and runtime nodes still require hands-on verification. The historical check-count breakdown below describes the earlier twenty-nine-suite baseline.

Gate: `sh tests/run_tests.sh <godot-binary>` - **292/292 test checks passed, 0 failed** across the twenty-nine suites (VRT 16, GSTM 12, RUIP 8, AHD 10, DQD 22, MNS 12, NLSS 9, A11Y 8, BED 7, DBP 8, SMG 9, CMV 8, PAR 9, AUD 8, MLH 7, IMX 9, SHD 9, SGS 10, LMX 10, BTD 10, COR 12, SDR 10, WBX 10, VFM 11, TMR 8, CTR 11, THM 11, PFG 8, DCG 10), plus every CLI smoke and exit-code-2 gate assertion in the same run. The gate runs automatically in CI (`.github/workflows/tests.yml`) on pushes to main and pull requests, green on both Godot 4.3.stable and 4.5.stable headless (Linux).

| Dimension | Score (1-5) | Evidence |
|---|---|---|
| Correctness | 4 | Per-tool suites pass on a fixture that contains one deliberate case per promised check; every one of the 29 CLIs is exercised by the gate, 25 of them including their exit-code-2 path. |
| Completeness vs brief | 5 | All 110 roadmap entries are implemented and checked. There are 133 addons, each with a core, an editor dock, a headless CLI, a fixture and tests; runtime nodes exist where a tool needs live data. The research entry ends in a recorded decision. |
| Code quality | 4 | One core operation per tool, no editor APIs in cores, docks/CLIs are thin shells; deterministic seeds where randomness exists. |
| Tests | 4 | Fixture-driven suites per tool plus CLI smoke and exit-code gates in one `run_tests.sh`. No coverage tooling for GDScript; suites assert behaviour, not lines. |
| UX / plain language | 4 | Every dock control has a tooltip and an offline `?` help text, and every finding carries a plain-words fix. All 133 docks pass a real-editor session. It is not a 5 because hands-on Windows use is still owed. |
| Safety / privacy | 5 | Fully offline; reads the project, writes only reports the user asked for; destructive-sounding actions (baseline approval, deleting unused files) are never performed automatically - approval is an explicit copy, deletion is only ever a suggestion. |
| Performance | 4 | All 39 project-wide scanners ran on a synthetic 4,623-file project in 20.8 s total: median 147 ms, worst 4.4 s (docs/performance.md). The two quadratic hotspots that run found are fixed. Real-project and Windows timing are still Unverified. |

Overall: gate green = shippable, with the limitations stated in README.md; unreleased additions on the way to the next version are tracked in CHANGELOG.md. No dimension is a Fail.

## Status (2026-10-31)

There are 133 addons, each with its own test suite. All 110 roadmap entries are checked; see ROADMAP.md for what a check requires. CI runs three kinds of evidence on every PR:

- **Gate** (`sh tests/run_tests.sh`, on Godot 4.3 and 4.5): every suite, CLI smoke test and exit-code-2 gate, plus the dock smoke suite. The dock smoke suite builds all 133 docks, checks every control's tooltip and runs each dock's action.
- **Real-editor session** (`tests/editor/run_editor_session.sh`, Godot 4.3, Xvfb, Mesa llvmpipe):
  - the windowed editor loads every plugin;
  - a test plugin brings each dock to the front, clicks its run button with real mouse events, and checks that output appears;
  - it takes a screenshot of each dock;
  - for Macro Recorder, it opens a scene, clicks Preview, and records an Inspector edit.
  All 133 docks pass.
- **Live-game session** (`tests/game/run_live_game.sh`): the 16 runtime nodes run in a windowed game with real frames, physics and input events, for 19 checks. A further check confirms that the subtitle layout measure matches a rendered Label. All 20 checks pass.
  - The live session found a real defect: `seed_replay`'s `randi_range`/`randf_range` called the engine's unseeded global `randf()`, so seeded replays diverged. It is fixed and covered by a regression test.

## Verification status

- Verified:
  - all core operations, CLI reports and CI gates on Godot 4.3-stable and 4.5-stable (Linux);
  - every editor dock in a real editor session;
  - every runtime node in a live game session.
  The two sessions run on Linux with software OpenGL; the clicks are synthetic mouse events delivered through the editor's own viewport.
- Partially Verified:
  - Four editor interactions are not automated: the capture runner's live viewport pass, the painted dialogue graph, the responsive-UI preview panes, and whitebox snapping of a live selection. Their docks do pass the editor session.
  - Estimator outputs are estimates, not measurements: thermal_sim device constants, batch_profiler draw calls, and Asset Health's per-platform GPU texture memory. Their comparative use is tested; real-device truth is not claimable here.
- Unverified: hands-on use on Windows with a GPU, timings on a real (non-synthetic) project, and Godot versions other than 4.3 and 4.5.
