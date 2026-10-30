# GodotDevTools - Project Rules

Prompt in force: The Elite Software Master Prompt v1.1 - Annex A (Godot / game tooling)
Purpose in one line: Nine Godot 4 editor plugins + headless CLIs for developer testing and project health, each built on a single core operation.
Frozen foundation: for every tool, `addons/<tool>/core/` holds the one operation; the editor dock, the CLI and the tests call it and add no checking logic of their own. Module layout per tool: core / ui / cli (+ runtime where a tool has an in-game piece). No tool depends on another tool.
Build: none (interpreted GDScript) - Full gate: `sh tests/run_tests.sh <godot-binary>` - Test corpus: `demo/` fixture project + `tests/test_*.gd`
Budgets: each scan should finish in seconds on a mid-size project (Unverified beyond the fixture); no network use, ever; deterministic seeded randomness in the network simulator so CI reproduces the same bad network.
Coverage floors: every promised check has at least one fixture case and one test check; every CLI is exercised by the gate, including its exit-code-2 path where it has one.
Special rules for this project: Godot 4.3 is the verified version - never claim another version works without a test run; binary or unparsable files are quarantined and reported, never guessed; natural-language search is rule-based and offline by design, and its results must always state why they matched; simulation results must be reproducible from a seed.
Known limitations live at: README.md "Limitations and known issues" - Decision log: this file - QUALITY.md: QUALITY.md
