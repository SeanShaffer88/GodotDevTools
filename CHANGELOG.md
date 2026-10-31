# Changelog

All notable changes to GodotDevTools are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow SemVer.

## [Unreleased]

### Added

- Started Player Telemetry Schema Validator with offline sample validation, explicit sensitive-field checks, dock, CLI and fixtures.

- Started Subtitle Timing and Readability Auditor with a JSON cue checker, dock, CLI and fixture tests.

- Started the Naming and Folder Convention Enforcer with a read-only file/folder regex audit, dock, CLI and fixture tests.

- Added a 50-tool roadmap and an initial Demo-to-Release Content Guard addon for reviewing development markers.

- Scene Dependency Map addon: browsable static dependency map, missing/cycle/chain checks, unused candidates and headless reports.

- **Suite expansion 9 -> 29**: twenty new tools, each with the frozen core/ui/cli layout (+ `runtime/` where the tool has an in-game half), a `demo/` fixture with one deliberate problem, a test suite, a CI exit-code-2 gate and a tool README: Draw Call and Batching Profiler (`batch_profiler`), Hot-Reloadable Schema and Save-Game Migrator (`schema_migrator`), Physics Collision Matrix Visualizer (`collision_matrix`), Procedural Animation Rigging Helper (`proc_anim`), Audio Bus and Dynamic Mixing Sandbox (`audio_sandbox`), Memory Leak and Orphan Node Hunter (`leak_hunter`), Multi-Platform Input Matrix and Rebinding Suite (`input_matrix`), Shader Doctor (`shader_doctor`), Signal Flow and Event Bus Spy (`signal_spy`), Localization Matrix and In-Context Previewer (`l10n_matrix`), Behaviour Tree and State Machine Debugger (`bt_debugger`), Camera Shake/Transition/Framing Orchestrator (`camera_orch`), Deterministic Seed and Replay Runner (`seed_replay`), Level Whiteboxing and Snapping Suite (`whitebox`), Cross-Platform Virtual Filesystem Mock (`vfs_mock`), Tilemap Rule and Autotile Generator (`tilemap_rules`), CI and Headless Test Runner (`test_runner`), Mobile Thermal and Battery Drain Emulation Dock (`thermal_sim`), Smart Prefab and Variant Instance Manager (`prefab_guard`), Automated Documentation Generator for GDScript (`doc_gen`).
- Eight new runtime nodes, each sharing its tool's core: collision contact counter, procedural two-bone rig, orphan watcher (weakref sweep), in-game rebinder with user:// saves, self-spying event bus, behaviour agent, camera rig (deadzone framing + seeded shake), and a recorded deterministic RNG.
- Honesty labels carried through READMEs/PARITY: thermal and draw-call numbers are documented estimates; the shader tool is a static `.gdshader` analyzer (no graph-to-code compilation); the localization tool does no network and no machine translation; the test runner detects GUT from text but never depends on it; the prefab guard writes scenes only with explicit `--apply`; leak-hunter static findings are suspects the runtime watcher confirms.
- Tests: 20 new suites, 189 new checks (DBP 8, SMG 9, CMV 8, PAR 9, AUD 8, MLH 7, IMX 9, SHD 9, SGS 10, LMX 10, BTD 10, COR 12, SDR 10, WBX 10, VFM 11, TMR 8, CTR 12, THM 11, PFG 8, DCG 10); the suite total is now 293.
- `tests/run_tests.sh`: 29-suite loop, a `gate()` helper, 20 new exit-code-2 CLI gates plus smokes and artifact checks. `project.godot` enables the 20 new plugins (`[input]` untouched - the input fixture is `demo/input/actions.json`). `release.yml` zips all 29 tools.
- **CI**: `.github/workflows/tests.yml` runs the full gate (`sh tests/run_tests.sh`) on every push and pull request, headless on Linux, on Godot 4.3-stable (the verified gate) and 4.5-stable (experimental evidence, `continue-on-error`). Reports are uploaded as artifacts. Both runs are green.
- **Release automation**: `.github/workflows/release.yml` builds the per-tool and suite zips from `addons/` on any `v*` tag and publishes them as a GitHub Release - but only after reusing the test-gate workflow, so a release never ships red.
- **Visual Regression - one-click capture runner** (was the top roadmap item): `core/vrt_capture.gd` plans scene x resolution captures, instantiates each scene in an offscreen `SubViewport`, lets it settle, and saves `<scene>__<width>x<height>.png` into the capture folder the compare run reads. The dock has a Capture section (scene list, output folder, Capture now). The live pass needs a renderer, so it runs in the editor or a game window, never headless; the pure plan/path/report parts are test-covered.
- **Dialogue and Quest - drawn node-graph view** (was the second roadmap item): `core/dqd_layout.gd` computes a deterministic layered layout (BFS depth from the start, ghost boxes for missing targets, unreachable nodes parked below the deepest layer, issue flags from `analyse()`); the dock paints it in a scrollable pane with start/end/warning/ghost colouring and `[if]` tags on conditional choices.
- `CHANGELOG.md`, `CONTRIBUTING.md`, issue templates and a pull-request template.
- `AI_USAGE.md`: repo-aware guide for AI agents - a pasteable project prompt (where the tools are, what to inspect first, how to apply them), the exact file map with links, the demo-fixture index, the full CLI reference taken from the code (defaults, fail-on kinds, exit codes), and the rules for changing the repo. Linked from the README.
- Tests: 11 new checks (VRT 12 -> 16, DQD 15 -> 22); the suite total is now 104.

### Changed

- `dqd_graph.gd` issues now carry structured `node` / `target` fields so views can flag precisely without reparsing messages.
- README: requirements now name Godot 4.3 **and** 4.5 as verified (the CI gate runs on both); install and downloads sections point at GitHub Releases instead of repo-root zips.
- `QUALITY.md` and `docs/PARITY.md` record the CI runs, the new check counts, and the two roadmap items as built.

### Removed

- The ten `GodotDevTools-*-v1.0.0.zip` files from the repository root. Releases are the single home for the zips now (`.gitignore` already excluded `*.zip`; the tracked copies predated the rule). The v1.0.0 release assets remain downloadable.

## [1.0.0] - 2026-10-30

### Added

- Initial release: nine Godot 4 tools, each an independently installable addon with an editor dock, a headless CLI (JSON + Markdown reports, `--fail-on` exit-code-2 gates) and a fixture-driven test suite - Visual Regression Testing, Game-State Time Machine, Responsive UI Previewer, Asset Health Dashboard, Dialogue and Quest Debugger, Multiplayer Network Simulator, Natural-Language Scene Search, Automated Accessibility Checker, Build and Export Doctor.
- `demo/` fixture project with one deliberate problem per tool; `tests/run_tests.sh` full gate (93 checks on Godot 4.3.stable).
