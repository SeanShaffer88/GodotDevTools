# Changelog

All notable changes to GodotDevTools are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow SemVer.

## [Unreleased]

### Added

- **CI**: `.github/workflows/tests.yml` runs the full gate (`sh tests/run_tests.sh`) on every push and pull request, headless on Linux, on Godot 4.3-stable (the verified gate) and 4.5-stable (experimental evidence, `continue-on-error`). Reports are uploaded as artifacts. Both runs are green.
- **Release automation**: `.github/workflows/release.yml` builds the per-tool and suite zips from `addons/` on any `v*` tag and publishes them as a GitHub Release - but only after reusing the test-gate workflow, so a release never ships red.
- **Visual Regression - one-click capture runner** (was the top roadmap item): `core/vrt_capture.gd` plans scene x resolution captures, instantiates each scene in an offscreen `SubViewport`, lets it settle, and saves `<scene>__<width>x<height>.png` into the capture folder the compare run reads. The dock has a Capture section (scene list, output folder, Capture now). The live pass needs a renderer, so it runs in the editor or a game window, never headless; the pure plan/path/report parts are test-covered.
- **Dialogue and Quest - drawn node-graph view** (was the second roadmap item): `core/dqd_layout.gd` computes a deterministic layered layout (BFS depth from the start, ghost boxes for missing targets, unreachable nodes parked below the deepest layer, issue flags from `analyse()`); the dock paints it in a scrollable pane with start/end/warning/ghost colouring and `[if]` tags on conditional choices.
- `CHANGELOG.md`, `CONTRIBUTING.md`, issue templates and a pull-request template.
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
