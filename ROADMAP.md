# Development roadmap

This roadmap captures 110 proposed tools and components, not a promise that every design is already implemented or verified. Work proceeds incrementally: each addon needs a pure core, thin editor dock and headless CLI, fixture-driven tests, documentation and honest limitations. A checked item means its initial implementation is verified; in-progress items remain unchecked. See each addon README and CI for verification status. Priorities may change as requirements are refined.

## Performance and rendering

- [ ] **Frame-Time Spike Investigator** — correlate frame spikes with scene changes, node counts, physics and markers.
- [ ] **GPU Budget and Overdraw Analyzer** — highlight overdraw and estimate fill-rate pressure at target resolutions.
- [ ] **Texture Memory and Streaming Planner** (in progress) — Asset Health now totals source-side uncompressed estimates with an optional budget; platform-specific formats, actual streaming and hardware verification remain future work.
- [ ] **Shader Variant Budget Manager** — inventory shader variants and flag compilation and memory risks.
- [ ] **Startup and Scene-Load Profiler** — break down startup and transition costs.
- [ ] **Object Pool Advisor** (in progress) — `addons/pool_advisor`: scores instantiate() sites (per-frame, repeating, looped, self-freeing) and merges optional recorded spawn counts from a runtime counter; Godot 4.3 headless suite passed, editor and live-game sessions pending.
- [ ] **LOD and Visibility Range Planner** — flag missing LODs and problematic visibility distances.
- [ ] **Particle Budget Inspector** (in progress) — `addons/particle_budget`: static per-scene capacity (amount x amount_ratio, instanced children followed) against scene/emitter/CPU/preprocess budgets; Godot 4.3 headless suite passed, editor session pending.
- [ ] **Animation Performance Auditor** — identify excessive tracks, redundant keys and invisible updates.
- [ ] **Rendering Settings Compatibility Matrix** — compare features and fallbacks across renderers and targets.

## Physics, navigation and gameplay

- [ ] **Navigation Mesh Diagnostic Lab** — identify disconnected regions, bottlenecks and unreachable targets.
- [ ] **Character Controller Test Course** — exercise slopes, stairs, ledges, coyote time and jump height.
- [ ] **Physics Jitter and Tunneling Detector** — surface fast bodies, conflicting transforms and unstable settings.
- [ ] **Hitbox and Hurtbox Timeline Viewer** — inspect combat volumes alongside animation frames.
- [ ] **Spawn Point and Encounter Validator** — check blocked, unsafe or unreachable spawns.
- [ ] **AI Perception Debugger** — visualize sight, hearing, occlusion and detection decisions.
- [ ] **Gameplay Ability Simulator** — exercise costs, cooldowns, stacking and interrupts.
- [ ] **Procedural Generation Constraint Tester** — verify seeded layouts against connectivity and placement constraints.
- [ ] **World Boundary and Out-of-Bounds Auditor** — find possible escape routes and exposed kill zones.
- [ ] **Interaction Reachability Checker** — test whether interactables can be reached and activated.

## Content and workflow

- [ ] **Scene Change Impact Analyzer** (in progress) — reverse dependency walk added to Scene Dependency Map; Godot 4.3/4.5 CI passed; hands-on editor verification pending.
- [ ] **Scene Merge Conflict Assistant** — explain scene conflicts by node and property without silently rewriting files.
- [ ] **Resource Rename and Reference Assistant** (in progress) — read-only direct reference and transitive impact preview added; no automated rename, Godot 4.3/4.5 CI passed; hands-on editor verification pending.
- [ ] **Asset Import Preset Auditor** (in progress) — optional importer-specific preset checks added to Asset Health; Godot 4.3/4.5 CI passed; hands-on editor verification pending.
- [ ] **Project Cleanup Workbench** — collect unused candidates, duplicates and stale imports for review.
- [ ] **Naming and Folder Convention Enforcer** (in progress) — file/folder checks passed Godot 4.3/4.5 CI in PR #5; opt-in static node, signal and group checks added, Godot 4.3/4.5 CI passed, hands-on editor verification pending.
- [ ] **Scene Review Snapshot Generator** — generate reproducible scene inventories and diffs.
- [ ] **Editor Action Macro Recorder** — record and preview repeatable editor actions with undo support.
- [ ] **Node Property Drift Monitor** — compare node properties against team baselines.
- [ ] **Art-to-Engine Handoff Validator** — check model scale, orientation, materials, animation and collisions.

## Testing and reliability

- [ ] **Gameplay Scenario Test Builder** — compose repeatable actions and assertions.
- [ ] **Crash and Error Reproduction Packager** — bundle approved logs, settings and reproduction information.
- [ ] **Save Corruption and Recovery Tester** — inject invalid saves and verify recovery behavior.
- [ ] **State Transition Coverage Tracker** (in progress) — model and trace comparison passed Godot 4.3/4.5 CI in PR #11; explicit bounded runtime recording and optional continuity checks added, Godot 4.3/4.5 CI passed; a hands-on game/editor session remains.
- [ ] **Regression Test Prioritizer** (in progress) — exact-path mapping passed Godot 4.3/4.5 CI in PR #11; optional reverse dependency graph propagation added, Godot 4.3/4.5 CI passed, hands-on editor verification pending.
- [ ] **Property-Based Gameplay Tester** — generate bounded input sequences to check invariants.
- [ ] **Resource Load Failure Simulator** — test fallbacks for missing, invalid or delayed resources.
- [ ] **Pause, Focus, and Lifecycle Tester** — exercise pause, focus, resize and suspend/resume.
- [ ] **Screenshot Baseline Review Queue** (in progress) — fingerprinted local review metadata and decision history added to visual regression; Godot 4.3/4.5 CI passed; hands-on review pending. Baseline promotion remains manual.
- [ ] **Performance Regression Gate** (in progress) — scalar baseline comparison with absolute/relative noise tolerances passed Godot 4.3/4.5 CI in PR #8; hands-on editor verification pending.

## Shipping, accessibility and live operations

- [ ] **Controller Glyph and Prompt Validator** — check device-specific prompts for input actions.
- [ ] **Color-Vision and Contrast Previewer** — preview color-vision differences and color-only cues.
- [ ] **Subtitle Timing and Readability Auditor** (in progress) — JSON cue checks passed Godot 4.3/4.5 CI in PR #6; SRT/WebVTT subset import passed Godot 4.3/4.5 CI. Hands-on editor, safe-area and rendered-layout checks remain future work.
- [ ] **Platform Certification Checklist Runner** (in progress) — compare a user-defined checklist with recorded results; no certification claim. Godot 4.3/4.5 CI passed; hands-on editor verification pending.
- [ ] **Privacy and Permissions Auditor** — inventory permissions, collection points and endpoints for review.
- [ ] **Offline and Poor-Connection Test Harness** — simulate outages, timeouts and interrupted requests.
- [ ] **Build Size Attribution Explorer** (in progress) — actual staged-directory file sizes and budgets passed Godot 4.3/4.5 CI in PR #10; hands-on editor verification pending. Archive-internal source attribution remains future work.
- [ ] **Demo-to-Release Content Guard** (in progress) — flag configurable placeholder and development markers for review; initial static scanner passed the Godot 4.3/4.5 CI gate in PR #4; hands-on editor verification remains.
- [ ] **Feature Flag and Rollout Simulator** (in progress) — offline deterministic rollout and prerequisite simulation passed Godot 4.3/4.5 CI in PR #9; hands-on editor verification pending.
- [ ] **Player Telemetry Schema Validator** (in progress) — local event and field checks plus explicit sensitive-field review passed Godot 4.3/4.5 CI in PR #7; hands-on editor verification pending.

## Expansion (60 more) - editor productivity and code health

- [ ] **Scene Lint Rule Engine** (in progress) — `addons/scene_lint`: user-defined JSON rules over scene text (required children, forbidden properties, type constraints). Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Export Variable Range Auditor** (in progress) — `addons/export_ranges`: @export values in scenes outside their declared range hints, and numeric exports with no hint. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Node Path Breakage Detector** (in progress) — `addons/node_paths`: `$Path` and `get_node("...")` strings checked against the scene trees that own the script. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Autoload Dependency Graph** (in progress) — `addons/autoload_graph`: which autoloads reference which; flag cycles and init-order hazards. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Unused Signal and Method Finder** (in progress) — `addons/unused_symbols`: declared signals never emitted or connected, functions never referenced. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Typed GDScript Coverage Meter** (in progress) — `addons/type_coverage`: share of variables, parameters and returns with static types; ratchet gate. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Script Complexity Reporter** (in progress) — `addons/script_complexity`: per-function branch complexity, length and nesting depth with thresholds. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Duplicate Code Detector** (in progress) — `addons/duplicate_code`: normalized line-window clone detection across GDScript files. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Resource UID Integrity Checker** (in progress) — `addons/uid_integrity`: `uid://` references versus declared ext_resource and `.uid` sidecars. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Project Settings Drift Report** (in progress) — `addons/settings_drift`: compare `project.godot` against a committed baseline, key by key. Godot 4.3 headless suite and CLI gate passed; editor session pending.

## Expansion - gameplay data and balance

- [ ] **Loot Table and Economy Simulator** (in progress) — `addons/loot_sim`: seeded drop simulation, expected value, drought lengths and pity checks. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Difficulty Curve Analyzer** (in progress) — `addons/difficulty_curve`: enemy power against player power per level from data tables; spikes and dips. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Damage Formula Sandbox** (in progress) — `addons/damage_sandbox`: evaluate formulas over stat grids; flag negatives, overflows and non-monotonic results. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **XP Curve Planner** (in progress) — `addons/xp_curve`: time-to-level from XP tables and earn rates; flag walls and skips. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Crafting and Inventory Graph Validator** (in progress) — `addons/crafting_graph`: unobtainable items, recipe cycles, dead-end materials. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Achievement Reachability Checker** — unlock conditions against declared events and stats.
- [ ] **Wave Spawner Budget Planner** — wave definitions against concurrent-enemy and spawn-rate budgets.
- [ ] **Random Table Fairness Tester** — chi-square goodness of fit for weighted tables over seeded draws.
- [ ] **Save File Bloat Auditor** — save size by key path, growth across sample saves.
- [ ] **Dialogue Variable Lint** — variables read but never set, and set but never read, in dialogue data.

## Expansion - rendering, audio and assets

- [ ] **Font Glyph Coverage Checker** — characters used by translations against a font's cmap table.
- [ ] **Audio Loudness and Clipping Auditor** — WAV peak, RMS and clipped samples per file.
- [ ] **Audio Import Settings Auditor** — loop flags and compression mode against clip length and role.
- [ ] **Texture Atlas Packing Planner** — shelf-pack sprite sizes into atlas pages; waste and page count.
- [ ] **Texture Filter Consistency Checker** — pixel-art folders with filtering or mipmaps on, and the reverse.
- [ ] **Mesh Statistics Report** — vertex, index and primitive counts from glTF JSON against budgets.
- [ ] **3D Light and Shadow Cost Estimator** — shadow-casting lights and omni/spot counts per scene.
- [ ] **Environment Feature Cost Matrix** — WorldEnvironment features enabled per scene against target tiers.
- [ ] **Colour Palette Consistency Checker** — colours in themes and scenes against an approved palette (delta E).
- [ ] **Theme Resource Auditor** — theme override sprawl, inconsistent font sizes, unused theme types.

## Expansion - testing, CI and reliability

- [ ] **Flaky Test Detector** — rerun histories to flake rate per test, with quarantine suggestions.
- [ ] **Golden Data Snapshot Tester** — compare JSON outputs to goldens with path-level diffs.
- [ ] **Input Sequence Fuzzer** — seeded, bounded input sequences generated from the InputMap for replay.
- [ ] **Error Log Grouper** — group Godot error/warning output by normalized signature and count.
- [ ] **Log Warning Budget Gate** — warning and error counts in headless logs against a baseline.
- [ ] **GDScript Warning Baseline** — per-file warning-code counts that may only go down.
- [ ] **Scene Load Smoke Tester** — load and instantiate every scene headless; report failures.
- [ ] **State Trace Determinism Diff** — compare two recorded state traces and report the first divergence.
- [ ] **Micro-Benchmark Harness** — repeatable timed runs with JSON output that feeds the Performance Regression Gate.
- [ ] **GDScript Mutation Tester** — mutate operators in a core script and report mutants the suite fails to kill.

## Expansion - shipping, platform and live operations

- [ ] **Store Asset Validator** — icon and screenshot dimensions against a user-defined store profile.
- [ ] **Android Permissions Reviewer** — export preset permissions and features listed for human review.
- [ ] **Version Consistency Checker** — version strings across project settings, export presets and plugin configs.
- [ ] **Third-Party Notice Collector** — gather license files from addons and assets into a notices report.
- [ ] **Release Notes Generator** — group conventional-commit messages into draft release notes.
- [ ] **Content Descriptor Checklist** — user-defined content questionnaire with recorded answers; no rating claim.
- [ ] **Patch Delta Estimator** — changed, added and removed bytes between two staged builds.
- [ ] **Settings File Validator** — user settings files against a schema with defaults and ranges.
- [ ] **Accessibility Options Coverage** — expected player options (subtitles, remapping, text scale) located in project data.
- [ ] **Handheld Readiness Checklist** — 1280x800 layout, minimum text size and gamepad-only navigation checks.

## Expansion - shared components, runtimes and native crates (optional; no tool may depend on them)

- [ ] **Report Schema** — a documented JSON Schema for tool reports plus a validator.
- [ ] **Suite CLI Dispatcher** — one entry script that lists tools and runs any tool CLI by name.
- [ ] **SARIF Exporter** — convert tool reports to SARIF 2.1.0 for code-scanning views.
- [ ] **JUnit Exporter** — convert any tool report to JUnit XML for CI test views.
- [ ] **Static HTML Dashboard** — one offline HTML page summarizing every report in a folder.
- [ ] **Report Diff** — new, fixed and unchanged findings between two runs of a report.
- [ ] **Finding Suppression Baseline** — accepted findings with written justification, applied to reports.
- [ ] **Pre-commit Hook Installer** — opt-in git hook that runs chosen CLIs on staged files.
- [ ] **Reusable CI Action** — composite GitHub Action that downloads Godot and runs chosen gates.
- [ ] **Native Accelerator Crate (research)** — optional Rust gdext crate for hashing and scan hot paths, with GDScript fallbacks; build and platform support must be verified before any claim.
