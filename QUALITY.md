# GodotDevTools - Quality Scorecard

Gate: `sh tests/run_tests.sh <godot-binary>` - **104/104 test checks passed, 0 failed** across the nine suites (VRT 16, GSTM 12, RUIP 8, AHD 10, DQD 22, MNS 12, NLSS 9, A11Y 8, BED 7), plus every CLI smoke and exit-code-2 gate assertion in the same run. The gate runs automatically in CI (`.github/workflows/tests.yml`) on every push and pull request, green on both Godot 4.3.stable and 4.5.stable headless (Linux).

| Dimension | Score (1-5) | Evidence |
|---|---|---|
| Correctness | 4 | Per-tool suites pass on a fixture that contains one deliberate case per promised check; CLI exit-code gates verified for visual regression, asset health, dialogue, accessibility and export doctor. |
| Completeness vs brief | 4 | All nine requested tools built as installable addons with editor dock + CLI + tests. The two once-reduced brief items are now built: the one-click capture runner (dock Capture section + core `vrt_capture.gd`; live viewport pass is editor/game-only by nature) and the drawn dialogue node-graph (core `dqd_layout.gd` + dock GraphView pane). Both await a hands-on editor session for full verification, like the other dock surfaces. |
| Code quality | 4 | One core operation per tool, no editor APIs in cores, docks/CLIs are thin shells; deterministic seeds where randomness exists. |
| Tests | 4 | Fixture-driven suites per tool plus CLI smoke and exit-code gates in one `run_tests.sh`. No coverage tooling for GDScript; suites assert behaviour, not lines. |
| UX / plain language | 4 | Every dock control has a tooltip and an offline `?` help text; every finding carries a plain-words fix. Hands-on editor session still owed, so not a 5. |
| Safety / privacy | 5 | Fully offline; reads the project, writes only reports the user asked for; destructive-sounding actions (baseline approval, deleting unused files) are never performed automatically - approval is an explicit copy, deletion is only ever a suggestion. |
| Performance | 3 | Fixture scans are instant; large-project timing is Unverified (recorded in PROJECT_RULES budgets). |

Overall: gate green = shippable, with the limitations stated in README.md; unreleased additions on the way to the next version are tracked in CHANGELOG.md. No dimension is a Fail.

## Verification status

- Verified: all core operations (including the new `vrt_capture.gd` pure parts and `dqd_layout.gd`), CLI reports and CI gates, on Godot 4.3.stable **and 4.5.stable** headless (Linux) - the CI workflow runs the full gate on both on every push and pull request.
- Partially Verified: editor docks (headless editor import passes and plugin scripts parse; clicking through the docks in a real editor session is owed), the two runtime nodes (they wrap verified cores), the dock capture runner's live viewport pass and the drawn graph pane (their pure cores are verified; rendering needs a real editor session).
- Unverified: hands-on Windows editor use, large-project performance, Godot versions other than 4.3/4.5.
