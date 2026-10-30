# GodotDevTools - Quality Scorecard

Gate: `sh tests/run_tests.sh ~/workspace/tools/godot` on Godot 4.3.stable - **93/93 test checks passed, 0 failed** across the nine suites (VRT 12, GSTM 12, RUIP 8, AHD 10, DQD 15, MNS 12, NLSS 9, A11Y 8, BED 7), plus every CLI smoke and exit-code-2 gate assertion in the same run.

| Dimension | Score (1-5) | Evidence |
|---|---|---|
| Correctness | 4 | Per-tool suites pass on a fixture that contains one deliberate case per promised check; CLI exit-code gates verified for visual regression, asset health, dialogue, accessibility and export doctor. |
| Completeness vs brief | 4 | All nine requested tools built as installable addons with editor dock + CLI + tests. Two brief items are delivered in reduced form and documented as limitations: automatic in-editor screenshot capture (compare/highlight/approve are built; the shutter is the game's test scene) and a drawn dialogue node-graph (branch lists + full simulation are built). |
| Code quality | 4 | One core operation per tool, no editor APIs in cores, docks/CLIs are thin shells; deterministic seeds where randomness exists. |
| Tests | 4 | Fixture-driven suites per tool plus CLI smoke and exit-code gates in one `run_tests.sh`. No coverage tooling for GDScript; suites assert behaviour, not lines. |
| UX / plain language | 4 | Every dock control has a tooltip and an offline `?` help text; every finding carries a plain-words fix. Hands-on editor session still owed, so not a 5. |
| Safety / privacy | 5 | Fully offline; reads the project, writes only reports the user asked for; destructive-sounding actions (baseline approval, deleting unused files) are never performed automatically - approval is an explicit copy, deletion is only ever a suggestion. |
| Performance | 3 | Fixture scans are instant; large-project timing is Unverified (recorded in PROJECT_RULES budgets). |

Overall: gate green = shippable as v1.0.0 with the limitations stated in README.md. No dimension is a Fail.

## Verification status

- Verified: all core operations, CLI reports and CI gates, on Godot 4.3.stable headless (Linux).
- Partially Verified: editor docks (headless editor import passes and plugin scripts parse; clicking through the docks in a real editor session is owed) and the two runtime nodes (they wrap verified cores).
- Unverified: hands-on Windows editor use, large-project performance, Godot versions other than 4.3.
