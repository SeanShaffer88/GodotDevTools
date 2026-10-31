# Development roadmap

This roadmap captures 110 proposed tools and components, not a promise that every design is already implemented or verified. Work proceeds incrementally: each addon needs a pure core, thin editor dock and headless CLI, fixture-driven tests, documentation and honest limitations. A checked item means its initial implementation is verified; in-progress items remain unchecked. See each addon README and CI for verification status. Priorities may change as requirements are refined.

## Performance and rendering

- [ ] **Frame-Time Spike Investigator** (in progress) — `addons/frame_spikes`: correlate frame spikes with scene changes, node counts, physics and markers. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **GPU Budget and Overdraw Analyzer** (in progress) — `addons/overdraw`: highlight overdraw and estimate fill-rate pressure at target resolutions. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Texture Memory and Streaming Planner** (in progress) — Asset Health now totals source-side uncompressed estimates with an optional budget; platform-specific formats, actual streaming and hardware verification remain future work.
- [ ] **Shader Variant Budget Manager** (in progress) — `addons/shader_variants`: inventory shader variants and flag compilation and memory risks. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Startup and Scene-Load Profiler** (in progress) — `addons/load_profiler`: break down startup and transition costs. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Object Pool Advisor** (in progress) — `addons/pool_advisor`: scores instantiate() sites (per-frame, repeating, looped, self-freeing) and merges optional recorded spawn counts from a runtime counter; Godot 4.3 headless suite passed, editor and live-game sessions pending.
- [ ] **LOD and Visibility Range Planner** (in progress) — `addons/lod_planner`: flag missing LODs and problematic visibility distances. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Particle Budget Inspector** (in progress) — `addons/particle_budget`: static per-scene capacity (amount x amount_ratio, instanced children followed) against scene/emitter/CPU/preprocess budgets; Godot 4.3 headless suite passed, editor session pending.
- [ ] **Animation Performance Auditor** (in progress) — `addons/anim_audit`: identify excessive tracks, redundant keys and invisible updates. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Rendering Settings Compatibility Matrix** (in progress) — `addons/render_compat`: compare features and fallbacks across renderers and targets. Godot 4.3 headless suite and CLI gate passed; editor session pending.

## Physics, navigation and gameplay

- [ ] **Navigation Mesh Diagnostic Lab** (in progress) — `addons/navmesh_lab`: identify disconnected regions, bottlenecks and unreachable targets. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Character Controller Test Course** (in progress) — `addons/controller_course`: exercise slopes, stairs, ledges, coyote time and jump height. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Physics Jitter and Tunneling Detector** (in progress) — `addons/physics_jitter`: surface fast bodies, conflicting transforms and unstable settings. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Hitbox and Hurtbox Timeline Viewer** (in progress) — `addons/hitbox_timeline`: inspect combat volumes alongside animation frames. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Spawn Point and Encounter Validator** (in progress) — `addons/spawn_validator`: check blocked, unsafe or unreachable spawns. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **AI Perception Debugger** (in progress) — `addons/ai_perception`: visualize sight, hearing, occlusion and detection decisions. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Gameplay Ability Simulator** (in progress) — `addons/ability_sim`: exercise costs, cooldowns, stacking and interrupts. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Procedural Generation Constraint Tester** (in progress) — `addons/procgen_constraints`: verify seeded layouts against connectivity and placement constraints. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **World Boundary and Out-of-Bounds Auditor** (in progress) — `addons/world_bounds`: find possible escape routes and exposed kill zones. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Interaction Reachability Checker** (in progress) — `addons/interaction_reach`: test whether interactables can be reached and activated. Godot 4.3 headless suite and CLI gate passed; editor session pending.

## Content and workflow

- [ ] **Scene Change Impact Analyzer** (in progress) — reverse dependency walk added to Scene Dependency Map; Godot 4.3/4.5 CI passed; hands-on editor verification pending.
- [ ] **Scene Merge Conflict Assistant** (in progress) — `addons/merge_conflicts`: explain scene conflicts by node and property without silently rewriting files. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Resource Rename and Reference Assistant** (in progress) — read-only direct reference and transitive impact preview added; no automated rename, Godot 4.3/4.5 CI passed; hands-on editor verification pending.
- [ ] **Asset Import Preset Auditor** (in progress) — optional importer-specific preset checks added to Asset Health; Godot 4.3/4.5 CI passed; hands-on editor verification pending.
- [ ] **Project Cleanup Workbench** (in progress) — `addons/cleanup_workbench`: collect unused candidates, duplicates and stale imports for review. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Naming and Folder Convention Enforcer** (in progress) — file/folder checks passed Godot 4.3/4.5 CI in PR #5; opt-in static node, signal and group checks added, Godot 4.3/4.5 CI passed, hands-on editor verification pending.
- [ ] **Scene Review Snapshot Generator** (in progress) — `addons/scene_snapshot`: generate reproducible scene inventories and diffs. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Editor Action Macro Recorder** — record and preview repeatable editor actions with undo support.
- [ ] **Node Property Drift Monitor** (in progress) — `addons/property_drift`: compare node properties against team baselines. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Art-to-Engine Handoff Validator** (in progress) — `addons/art_handoff`: check model scale, orientation, materials, animation and collisions. Godot 4.3 headless suite and CLI gate passed; editor session pending.

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

- [ ] **Controller Glyph and Prompt Validator** (in progress) — `addons/controller_glyphs`: check device-specific prompts for input actions. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Color-Vision and Contrast Previewer** (in progress) — `addons/colorvision`: preview color-vision differences and color-only cues. Godot 4.3 headless suite and CLI gate passed; editor session pending.
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
- [ ] **Achievement Reachability Checker** (in progress) — `addons/achievements`: unlock conditions against declared events and stats. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Wave Spawner Budget Planner** (in progress) — `addons/wave_budget`: wave definitions against concurrent-enemy and spawn-rate budgets. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Random Table Fairness Tester** (in progress) — `addons/rng_fairness`: chi-square goodness of fit for weighted tables over seeded draws. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Save File Bloat Auditor** (in progress) — `addons/save_bloat`: save size by key path, growth across sample saves. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Dialogue Variable Lint** (in progress) — `addons/dialogue_vars`: variables read but never set, and set but never read, in dialogue data. Godot 4.3 headless suite and CLI gate passed; editor session pending.

## Expansion - rendering, audio and assets

- [ ] **Font Glyph Coverage Checker** (in progress) — `addons/font_glyphs`: characters used by translations against a font's cmap table. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Audio Loudness and Clipping Auditor** (in progress) — `addons/audio_levels`: WAV peak, RMS and clipped samples per file. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Audio Import Settings Auditor** (in progress) — `addons/audio_import`: loop flags and compression mode against clip length and role. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Texture Atlas Packing Planner** (in progress) — `addons/atlas_planner`: shelf-pack sprite sizes into atlas pages; waste and page count. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Texture Filter Consistency Checker** (in progress) — `addons/texture_filter`: pixel-art folders with filtering or mipmaps on, and the reverse. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Mesh Statistics Report** (in progress) — `addons/mesh_stats`: vertex, index and primitive counts from glTF JSON against budgets. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **3D Light and Shadow Cost Estimator** (in progress) — `addons/light_cost`: shadow-casting lights and omni/spot counts per scene. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Environment Feature Cost Matrix** (in progress) — `addons/env_cost`: WorldEnvironment features enabled per scene against target tiers. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Colour Palette Consistency Checker** (in progress) — `addons/palette_check`: colours in themes and scenes against an approved palette (delta E). Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Theme Resource Auditor** (in progress) — `addons/theme_audit`: theme override sprawl, inconsistent font sizes, unused theme types. Godot 4.3 headless suite and CLI gate passed; editor session pending.

## Expansion - testing, CI and reliability

- [ ] **Flaky Test Detector** (in progress) — `addons/flaky_tests`: rerun histories to flake rate per test, with quarantine suggestions. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Golden Data Snapshot Tester** (in progress) — `addons/golden_snapshot`: compare JSON outputs to goldens with path-level diffs. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Input Sequence Fuzzer** (in progress) — `addons/input_fuzzer`: seeded, bounded input sequences generated from the InputMap for replay. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Error Log Grouper** (in progress) — `addons/log_grouper`: group Godot error/warning output by normalized signature and count. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Log Warning Budget Gate** (in progress) — `addons/log_budget`: warning and error counts in headless logs against a baseline. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **GDScript Warning Baseline** (in progress) — `addons/warning_baseline`: per-file warning-code counts that may only go down. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Scene Load Smoke Tester** (in progress) — `addons/scene_smoke`: load and instantiate every scene headless; report failures. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **State Trace Determinism Diff** (in progress) — `addons/trace_diff`: compare two recorded state traces and report the first divergence. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Micro-Benchmark Harness** (in progress) — `addons/bench_harness`: repeatable timed runs with JSON output that feeds the Performance Regression Gate. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **GDScript Mutation Tester** (in progress) — `addons/mutation_tester`: mutate operators in a core script and report mutants the suite fails to kill. Godot 4.3 headless suite and CLI gate passed; editor session pending.

## Expansion - shipping, platform and live operations

- [ ] **Store Asset Validator** (in progress) — `addons/store_assets`: icon and screenshot dimensions against a user-defined store profile. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Android Permissions Reviewer** (in progress) — `addons/android_permissions`: export preset permissions and features listed for human review. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Version Consistency Checker** (in progress) — `addons/version_consistency`: version strings across project settings, export presets and plugin configs. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Third-Party Notice Collector** (in progress) — `addons/third_party_notices`: gather license files from addons and assets into a notices report. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Release Notes Generator** (in progress) — `addons/release_notes`: group conventional-commit messages into draft release notes. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Content Descriptor Checklist** (in progress) — `addons/content_descriptor`: user-defined content questionnaire with recorded answers; no rating claim. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Patch Delta Estimator** (in progress) — `addons/patch_delta`: changed, added and removed bytes between two staged builds. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Settings File Validator** (in progress) — `addons/settings_validator`: user settings files against a schema with defaults and ranges. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Accessibility Options Coverage** (in progress) — `addons/a11y_options`: expected player options (subtitles, remapping, text scale) located in project data. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Handheld Readiness Checklist** (in progress) — `addons/handheld_readiness`: 1280x800 layout, minimum text size and gamepad-only navigation checks. Godot 4.3 headless suite and CLI gate passed; editor session pending.

## Expansion - shared components, runtimes and native crates (optional; no tool may depend on them)

- [ ] **Report Schema** (in progress) — `addons/report_schema`: a documented JSON Schema for tool reports plus a validator. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Suite CLI Dispatcher** (in progress) — `addons/suite_dispatcher`: one entry script that lists tools and runs any tool CLI by name. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **SARIF Exporter** (in progress) — `addons/sarif_export`: convert tool reports to SARIF 2.1.0 for code-scanning views. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **JUnit Exporter** (in progress) — `addons/junit_export`: convert any tool report to JUnit XML for CI test views. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Static HTML Dashboard** (in progress) — `addons/html_dashboard`: one offline HTML page summarizing every report in a folder. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Report Diff** (in progress) — `addons/report_diff`: new, fixed and unchanged findings between two runs of a report. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Finding Suppression Baseline** (in progress) — `addons/suppressions`: accepted findings with written justification, applied to reports. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Pre-commit Hook Installer** (in progress) — `addons/precommit`: opt-in git hook that runs chosen CLIs on staged files. Godot 4.3 headless suite and CLI gate passed; editor session pending.
- [ ] **Reusable CI Action** (in progress) — `.github/actions/godot-dev-tools`: composite action that downloads Godot, imports the project and runs dispatcher commands; exercised by this repo's `action-smoke` CI job.
- [ ] **Native Accelerator Crate (research)** — research note in `docs/native-accelerator.md`: measured GDScript hot paths; recommendation is not to build yet; no crate built (crates.io unreachable here), every native-speed claim unverified.
