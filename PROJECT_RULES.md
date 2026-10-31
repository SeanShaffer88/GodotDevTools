# GodotDevTools - Project Rules

Prompt in force: The Elite Software Master Prompt v1.1 - Annex A (Godot / game tooling)
Purpose in one line: Nine Godot 4 editor plugins + headless CLIs for developer testing and project health, each built on a single core operation.
Frozen foundation: for every tool, `addons/<tool>/core/` holds the one operation; the editor dock, the CLI and the tests call it and add no checking logic of their own. Module layout per tool: core / ui / cli (+ runtime where a tool has an in-game piece). No tool depends on another tool.
Build: none (interpreted GDScript) - Full gate: `sh tests/run_tests.sh <godot-binary>` - Test corpus: `demo/` fixture project + `tests/test_*.gd`
Budgets: each scan should finish in seconds on a mid-size project (Unverified beyond the fixture); no network use, ever; deterministic seeded randomness in the network simulator so CI reproduces the same bad network.
Coverage floors: every promised check has at least one fixture case and one test check; every CLI is exercised by the gate, including its exit-code-2 path where it has one.
Special rules for this project: Godot 4.3 is the verified version - never claim another version works without a test run; binary or unparsable files are quarantined and reported, never guessed; natural-language search is rule-based and offline by design, and its results must always state why they matched; simulation results must be reproducible from a seed.
Known limitations live at: README.md "Limitations and known issues" - Decision log: this file - QUALITY.md: QUALITY.md

## Decision log

- 2026-10-30: CI added (`.github/workflows/tests.yml`) - the full gate runs headless on every push/PR on Godot 4.3-stable (the hard gate) and 4.5-stable (experimental, continue-on-error, evidence only). Both green from the first run: 4.5-stable is the first non-4.3 version verified by a test run, per the version rule above.
- 2026-10-30: The two documented roadmap items are built: the one-click capture runner (visual_regression `core/vrt_capture.gd` + dock Capture section; live pass needs a renderer, so it is Partially Verified like other dock surfaces) and the drawn dialogue node-graph (dialogue_quest `core/dqd_layout.gd` + dock GraphView; layout maths Verified, painting Partially Verified). Suite grew 93 -> 104 checks (VRT 16, DQD 22); dqd_graph issues now carry structured node/target fields so views flag without reparsing messages.
- 2026-10-30: Release zips untracked from the repo root (they predated the `*.zip` ignore rule); `.github/workflows/release.yml` now builds per-tool + suite zips from `addons/` on any `v*` tag and publishes them as a GitHub Release, reusing the test-gate workflow first so a release never ships red. CONTRIBUTING.md documents cutting a release.
- 2026-10-30: Contributor surface added: CHANGELOG.md (Keep a Changelog), CONTRIBUTING.md (the frozen core/ui/cli rule, gate, coverage floor, release process), issue templates (bug report asks for gate status; feature request asks where the logic would live) and a PR template with an evidence checklist.
- 2026-10-31: AI_USAGE.md added: the repo-aware guide for AI agents - a pasteable project prompt plus the file map, inspection order, demo-fixture index and the CLI reference transcribed from the code itself (defaults, fail-on kinds, exit codes), linked from README.md. Rule for it: when code and documentation disagree, the code wins and the docs get fixed.
