# GodotDevTools - Quality Scorecard

The forty-suite gate passed headless CI on Godot 4.3 and 4.5 on main (run 41168830957); suites added after that run are listed in CHANGELOG.md and gated by the same `run_tests.sh`. Editor docks and runtime nodes still require hands-on verification. The historical check-count breakdown below describes the earlier twenty-nine-suite baseline.

Gate: `sh tests/run_tests.sh <godot-binary>` - **292/292 test checks passed, 0 failed** across the twenty-nine suites (VRT 16, GSTM 12, RUIP 8, AHD 10, DQD 22, MNS 12, NLSS 9, A11Y 8, BED 7, DBP 8, SMG 9, CMV 8, PAR 9, AUD 8, MLH 7, IMX 9, SHD 9, SGS 10, LMX 10, BTD 10, COR 12, SDR 10, WBX 10, VFM 11, TMR 8, CTR 11, THM 11, PFG 8, DCG 10), plus every CLI smoke and exit-code-2 gate assertion in the same run. The gate runs automatically in CI (`.github/workflows/tests.yml`) on pushes to main and pull requests, green on both Godot 4.3.stable and 4.5.stable headless (Linux).

| Dimension | Score (1-5) | Evidence |
|---|---|---|
| Correctness | 4 | Per-tool suites pass on a fixture that contains one deliberate case per promised check; every one of the 29 CLIs is exercised by the gate, 25 of them including their exit-code-2 path. |
| Completeness vs brief | 4 | All twenty-nine requested tools built as installable addons with editor dock + CLI + tests (the original nine plus the twenty-tool expansion). The two once-reduced brief items are built (capture runner, drawn dialogue graph), and the expansion's honest-scope labels (estimates, static analysis, no-network localization) are documented per tool. Dock surfaces await a hands-on editor session for full verification. |
| Code quality | 4 | One core operation per tool, no editor APIs in cores, docks/CLIs are thin shells; deterministic seeds where randomness exists. |
| Tests | 4 | Fixture-driven suites per tool plus CLI smoke and exit-code gates in one `run_tests.sh`. No coverage tooling for GDScript; suites assert behaviour, not lines. |
| UX / plain language | 4 | Every dock control has a tooltip and an offline `?` help text; every finding carries a plain-words fix. Hands-on editor session still owed, so not a 5. |
| Safety / privacy | 5 | Fully offline; reads the project, writes only reports the user asked for; destructive-sounding actions (baseline approval, deleting unused files) are never performed automatically - approval is an explicit copy, deletion is only ever a suggestion. |
| Performance | 3 | Fixture scans are instant; large-project timing is Unverified (recorded in PROJECT_RULES budgets). |

Overall: gate green = shippable, with the limitations stated in README.md; unreleased additions on the way to the next version are tracked in CHANGELOG.md. No dimension is a Fail.

## Verification status

- Verified: all core operations (including `vrt_capture.gd` pure parts, `dqd_layout.gd`, and the twenty expansion cores), CLI reports and CI gates, on Godot 4.3.stable **and 4.5.stable** headless (Linux) - the CI workflow runs the full gate on both on pushes to main and pull requests.
- Partially Verified: editor docks (headless editor import passes and plugin scripts parse; clicking through the docks in a real editor session is owed), the ten runtime nodes (they wrap verified cores; a live game session is owed), the dock capture runner's live viewport pass and the drawn graph pane (their pure cores are verified; rendering needs a real editor session), and the estimator tools' absolute numbers (thermal_sim device constants and batch_profiler draw-call counts are documented estimates - their comparative use is verified by tests, real-device truth is not claimable here).
- Unverified: hands-on Windows editor use, large-project performance, Godot versions other than 4.3/4.5.
