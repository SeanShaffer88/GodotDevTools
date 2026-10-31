# Contributing to GodotDevTools

Thanks for taking a tool off the workshop wall. This file explains how the
project is put together and what a change needs before it can merge.

## The one rule

Every tool is frozen into the same shape (see `PROJECT_RULES.md`):

```
addons/<tool>/
  core/     the one operation - no editor APIs, fully testable headless
  ui/       the editor dock - a thin shell over core, adds no checking logic
  cli/      the headless runner - a thin shell over core, writes reports
  runtime/  (some tools) in-game nodes that wrap core
```

If you add a check, it belongs in `core/`. If you add a button, it belongs in
`ui/` and calls `core/`. Docks, CLIs and tests must never grow checking logic
of their own - that is what keeps the three surfaces telling the same truth.
No tool may depend on another tool. No network use, ever.

## Running the gate

You need a Godot 4.3+ binary (4.3-stable and 4.5-stable are CI-verified):

```sh
sh tests/run_tests.sh /path/to/godot
```

The gate imports the project, runs the nine suites in `tests/`, and exercises
every CLI including its exit-code-2 path on the `demo/` fixture. It ends with
`ALL GATE CHECKS PASSED` or fails loudly. CI runs the same script on every
push and pull request - there is no separate CI-only test path.

## What a change needs

- **A new or changed check**: a fixture case in `demo/` that contains the
  problem, and at least one `_check(...)` in the tool's `tests/test_*.gd`.
  The coverage floor is: every promised check has a fixture case and a test.
- **A new CLI flag**: header comment in the CLI script updated (it is the
  authoritative option list), and a smoke or gate line in `run_tests.sh`
  where the flag changes exit behaviour.
- **Docs**: the tool's `addons/<tool>/README.md` for user-visible behaviour;
  the root `README.md` limitations list if the change moves a known limit;
  `docs/PARITY.md` if a capability's verification status changes;
  `CHANGELOG.md` under `[Unreleased]`, always.
- **Honest status labels**: "Verified" means a test check or CI run proves
  it. Editor-rendered surfaces that CI cannot exercise are "Partially
  Verified" at best until someone clicks through them in a real editor.
  Never claim a Godot version works without a test run.

## Pull requests

Open the PR against `main`. CI must be green on the 4.3 job before merge;
the 4.5 job is informational. Keep one tool per PR where practical - the
tools are independent and so are their reviews.

## Releases

Releases are cut from tags, not from hand-made zips:

1. Update `CHANGELOG.md`: rename `[Unreleased]` to the new version + date,
   start a fresh empty `[Unreleased]`.
2. Bump `version` in every `addons/*/plugin.cfg` being released.
3. Tag and push: `git tag v1.2.0 && git push origin v1.2.0`.
4. The release workflow re-runs the full gate, then builds
   `GodotDevTools-<Tool>-v1.2.0.zip` per tool plus
   `GodotDevTools-Suite-v1.2.0.zip` and attaches them to a GitHub Release.

If the gate fails, no release is published - fix forward and tag again.

## Style

GDScript with 4-space indentation, typed where practical, `##` doc comments
on every public function, plain-words messages in every finding (each carries
a `fix` a human can act on). Match the surrounding files; the codebase reads
as one voice on purpose.
