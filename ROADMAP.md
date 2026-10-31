# Development roadmap

This roadmap captures 110 tools and components. All 110 are implemented; the shared research item ended in a recorded decision not to build. Work proceeds incrementally: each addon needs a pure core, thin editor dock and headless CLI, fixture-driven tests, documentation and honest limitations. A checked item means its core passes its headless suite and CLI gate in CI on Godot 4.3 and 4.5, its dock passes a real-editor session (`tests/editor/run_editor_session.sh`), and any runtime node passes a live game session (`tests/game/run_live_game.sh`); both sessions run in CI. See each addon README and CI for verification status. Priorities may change as requirements are refined.

## Performance and rendering

- [x] **Frame-Time Spike Investigator** — `addons/frame_spikes`: correlate frame spikes with scene changes, node counts, physics and markers. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`); runtime node exercised in a live game (`tests/game`).
- [x] **GPU Budget and Overdraw Analyzer** — `addons/overdraw`: highlight overdraw and estimate fill-rate pressure at target resolutions. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Texture Memory and Streaming Planner** — Asset Health: source-size totals plus per-platform GPU estimates from import settings (BC1/BC3/BC7/BC5 desktop, ETC2/ASTC mobile, size limits, block rounding, mipmaps) with `--desktop-budget`/`--mobile-budget`; dock driven in a real editor session (`tests/editor`). Godot 4.3 has no texture streaming to plan; numbers are estimates, not device measurements.
- [x] **Shader Variant Budget Manager** — `addons/shader_variants`: inventory shader variants and flag compilation and memory risks. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Startup and Scene-Load Profiler** — `addons/load_profiler`: break down startup and transition costs. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Object Pool Advisor** — `addons/pool_advisor`: scores instantiate() sites (per-frame, repeating, looped, self-freeing) and merges optional recorded spawn counts from a runtime counter; headless suite passes on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`); runtime node exercised in a live game (`tests/game`).
- [x] **LOD and Visibility Range Planner** — `addons/lod_planner`: flag missing LODs and problematic visibility distances. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Particle Budget Inspector** — `addons/particle_budget`: static per-scene capacity (amount x amount_ratio, instanced children followed) against scene/emitter/CPU/preprocess budgets; headless suite passes on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Animation Performance Auditor** — `addons/anim_audit`: identify excessive tracks, redundant keys and invisible updates. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Rendering Settings Compatibility Matrix** — `addons/render_compat`: compare features and fallbacks across renderers and targets. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Physics, navigation and gameplay

- [x] **Navigation Mesh Diagnostic Lab** — `addons/navmesh_lab`: identify disconnected regions, bottlenecks and unreachable targets. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Character Controller Test Course** — `addons/controller_course`: exercise slopes, stairs, ledges, coyote time and jump height. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Physics Jitter and Tunneling Detector** — `addons/physics_jitter`: surface fast bodies, conflicting transforms and unstable settings. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Hitbox and Hurtbox Timeline Viewer** — `addons/hitbox_timeline`: inspect combat volumes alongside animation frames. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Spawn Point and Encounter Validator** — `addons/spawn_validator`: check blocked, unsafe or unreachable spawns. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **AI Perception Debugger** — `addons/ai_perception`: visualize sight, hearing, occlusion and detection decisions. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Gameplay Ability Simulator** — `addons/ability_sim`: exercise costs, cooldowns, stacking and interrupts. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Procedural Generation Constraint Tester** — `addons/procgen_constraints`: verify seeded layouts against connectivity and placement constraints. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **World Boundary and Out-of-Bounds Auditor** — `addons/world_bounds`: find possible escape routes and exposed kill zones. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Interaction Reachability Checker** — `addons/interaction_reach`: test whether interactables can be reached and activated. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Content and workflow

- [x] **Scene Change Impact Analyzer** — reverse dependency walk in Scene Dependency Map; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Scene Merge Conflict Assistant** — `addons/merge_conflicts`: explain scene conflicts by node and property without silently rewriting files. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Resource Rename and Reference Assistant** — read-only direct reference and transitive impact preview in Scene Dependency Map (deliberately no automated rename); Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Asset Import Preset Auditor** — importer-specific preset checks in Asset Health; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Project Cleanup Workbench** — `addons/cleanup_workbench`: collect unused candidates, duplicates and stale imports for review. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Naming and Folder Convention Enforcer** — file/folder checks plus opt-in node, signal and group checks; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Scene Review Snapshot Generator** — `addons/scene_snapshot`: generate reproducible scene inventories and diffs. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Editor Action Macro Recorder** — `addons/macro_recorder`: record and preview repeatable editor actions with undo support. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Node Property Drift Monitor** — `addons/property_drift`: compare node properties against team baselines. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Art-to-Engine Handoff Validator** — `addons/art_handoff`: check model scale, orientation, materials, animation and collisions. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Testing and reliability

- [x] **Gameplay Scenario Test Builder** — `addons/scenario_tests`: compose repeatable actions and assertions. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`); runtime node exercised in a live game (`tests/game`).
- [x] **Crash and Error Reproduction Packager** — `addons/crash_packager`: bundle approved logs, settings and reproduction information. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Save Corruption and Recovery Tester** — `addons/save_corruption`: inject invalid saves and verify recovery behavior. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **State Transition Coverage Tracker** — model/trace comparison and bounded runtime recording; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`); runtime node exercised in a live game (`tests/game`).
- [x] **Regression Test Prioritizer** — exact-path mapping with reverse-dependency propagation; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Property-Based Gameplay Tester** — `addons/property_tests`: generate bounded input sequences to check invariants. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Resource Load Failure Simulator** — `addons/load_failure`: test fallbacks for missing, invalid or delayed resources. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Pause, Focus, and Lifecycle Tester** — `addons/lifecycle`: exercise pause, focus, resize and suspend/resume. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Screenshot Baseline Review Queue** — fingerprinted review metadata and decision history in Visual Regression; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`). Baseline promotion stays a manual, explicit copy by design.
- [x] **Performance Regression Gate** — scalar baseline comparison with absolute/relative noise tolerances; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).

## Shipping, accessibility and live operations

- [x] **Controller Glyph and Prompt Validator** — `addons/controller_glyphs`: check device-specific prompts for input actions. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Color-Vision and Contrast Previewer** — `addons/colorvision`: preview color-vision differences and color-only cues. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Subtitle Timing and Readability Auditor** — JSON/SRT/WebVTT timing checks plus opt-in rendered layout (engine TextParagraph wrapping in a safe-area box, cross-checked against a rendered Label in `tests/game`); Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Platform Certification Checklist Runner** — compares a user-defined checklist with recorded results (no certification claim); Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Privacy and Permissions Auditor** — `addons/privacy_audit`: inventory permissions, collection points and endpoints for review. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Offline and Poor-Connection Test Harness** — `addons/offline_harness`: simulate outages, timeouts and interrupted requests. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`); runtime node exercised in a live game (`tests/game`).
- [x] **Build Size Attribution Explorer** — staged-directory sizes and budgets plus attribution inside Godot packs (format 2 and 3, standalone or embedded in an executable), tested against packs written by Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Demo-to-Release Content Guard** — configurable placeholder and development-marker scan; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Feature Flag and Rollout Simulator** — offline deterministic rollout and prerequisite simulation; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).
- [x] **Player Telemetry Schema Validator** — local event/field checks with explicit sensitive-field review; Godot 4.3/4.5 CI; dock driven in a real editor session (`tests/editor`).

## Expansion (60 more) - editor productivity and code health

- [x] **Scene Lint Rule Engine** — `addons/scene_lint`: user-defined JSON rules over scene text (required children, forbidden properties, type constraints). Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Export Variable Range Auditor** — `addons/export_ranges`: @export values in scenes outside their declared range hints, and numeric exports with no hint. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Node Path Breakage Detector** — `addons/node_paths`: `$Path` and `get_node("...")` strings checked against the scene trees that own the script. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Autoload Dependency Graph** — `addons/autoload_graph`: which autoloads reference which; flag cycles and init-order hazards. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Unused Signal and Method Finder** — `addons/unused_symbols`: declared signals never emitted or connected, functions never referenced. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Typed GDScript Coverage Meter** — `addons/type_coverage`: share of variables, parameters and returns with static types; ratchet gate. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Script Complexity Reporter** — `addons/script_complexity`: per-function branch complexity, length and nesting depth with thresholds. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Duplicate Code Detector** — `addons/duplicate_code`: normalized line-window clone detection across GDScript files. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Resource UID Integrity Checker** — `addons/uid_integrity`: `uid://` references versus declared ext_resource and `.uid` sidecars. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Project Settings Drift Report** — `addons/settings_drift`: compare `project.godot` against a committed baseline, key by key. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Expansion - gameplay data and balance

- [x] **Loot Table and Economy Simulator** — `addons/loot_sim`: seeded drop simulation, expected value, drought lengths and pity checks. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Difficulty Curve Analyzer** — `addons/difficulty_curve`: enemy power against player power per level from data tables; spikes and dips. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Damage Formula Sandbox** — `addons/damage_sandbox`: evaluate formulas over stat grids; flag negatives, overflows and non-monotonic results. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **XP Curve Planner** — `addons/xp_curve`: time-to-level from XP tables and earn rates; flag walls and skips. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Crafting and Inventory Graph Validator** — `addons/crafting_graph`: unobtainable items, recipe cycles, dead-end materials. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Achievement Reachability Checker** — `addons/achievements`: unlock conditions against declared events and stats. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Wave Spawner Budget Planner** — `addons/wave_budget`: wave definitions against concurrent-enemy and spawn-rate budgets. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Random Table Fairness Tester** — `addons/rng_fairness`: chi-square goodness of fit for weighted tables over seeded draws. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Save File Bloat Auditor** — `addons/save_bloat`: save size by key path, growth across sample saves. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Dialogue Variable Lint** — `addons/dialogue_vars`: variables read but never set, and set but never read, in dialogue data. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Expansion - rendering, audio and assets

- [x] **Font Glyph Coverage Checker** — `addons/font_glyphs`: characters used by translations against a font's cmap table. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Audio Loudness and Clipping Auditor** — `addons/audio_levels`: WAV peak, RMS and clipped samples per file. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Audio Import Settings Auditor** — `addons/audio_import`: loop flags and compression mode against clip length and role. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Texture Atlas Packing Planner** — `addons/atlas_planner`: shelf-pack sprite sizes into atlas pages; waste and page count. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Texture Filter Consistency Checker** — `addons/texture_filter`: pixel-art folders with filtering or mipmaps on, and the reverse. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Mesh Statistics Report** — `addons/mesh_stats`: vertex, index and primitive counts from glTF JSON against budgets. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **3D Light and Shadow Cost Estimator** — `addons/light_cost`: shadow-casting lights and omni/spot counts per scene. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Environment Feature Cost Matrix** — `addons/env_cost`: WorldEnvironment features enabled per scene against target tiers. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Colour Palette Consistency Checker** — `addons/palette_check`: colours in themes and scenes against an approved palette (delta E). Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Theme Resource Auditor** — `addons/theme_audit`: theme override sprawl, inconsistent font sizes, unused theme types. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Expansion - testing, CI and reliability

- [x] **Flaky Test Detector** — `addons/flaky_tests`: rerun histories to flake rate per test, with quarantine suggestions. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Golden Data Snapshot Tester** — `addons/golden_snapshot`: compare JSON outputs to goldens with path-level diffs. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Input Sequence Fuzzer** — `addons/input_fuzzer`: seeded, bounded input sequences generated from the InputMap for replay. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`); runtime node exercised in a live game (`tests/game`).
- [x] **Error Log Grouper** — `addons/log_grouper`: group Godot error/warning output by normalized signature and count. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Log Warning Budget Gate** — `addons/log_budget`: warning and error counts in headless logs against a baseline. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **GDScript Warning Baseline** — `addons/warning_baseline`: per-file warning-code counts that may only go down. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Scene Load Smoke Tester** — `addons/scene_smoke`: load and instantiate every scene headless; report failures. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **State Trace Determinism Diff** — `addons/trace_diff`: compare two recorded state traces and report the first divergence. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Micro-Benchmark Harness** — `addons/bench_harness`: repeatable timed runs with JSON output that feeds the Performance Regression Gate. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **GDScript Mutation Tester** — `addons/mutation_tester`: mutate operators in a core script and report mutants the suite fails to kill. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Expansion - shipping, platform and live operations

- [x] **Store Asset Validator** — `addons/store_assets`: icon and screenshot dimensions against a user-defined store profile. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Android Permissions Reviewer** — `addons/android_permissions`: export preset permissions and features listed for human review. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Version Consistency Checker** — `addons/version_consistency`: version strings across project settings, export presets and plugin configs. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Third-Party Notice Collector** — `addons/third_party_notices`: gather license files from addons and assets into a notices report. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Release Notes Generator** — `addons/release_notes`: group conventional-commit messages into draft release notes. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Content Descriptor Checklist** — `addons/content_descriptor`: user-defined content questionnaire with recorded answers; no rating claim. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Patch Delta Estimator** — `addons/patch_delta`: changed, added and removed bytes between two staged builds. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Settings File Validator** — `addons/settings_validator`: user settings files against a schema with defaults and ranges. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Accessibility Options Coverage** — `addons/a11y_options`: expected player options (subtitles, remapping, text scale) located in project data. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Handheld Readiness Checklist** — `addons/handheld_readiness`: 1280x800 layout, minimum text size and gamepad-only navigation checks. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).

## Expansion - shared components, runtimes and native crates (optional; no tool may depend on them)

- [x] **Report Schema** — `addons/report_schema`: a documented JSON Schema for tool reports plus a validator. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Suite CLI Dispatcher** — `addons/suite_dispatcher`: one entry script that lists tools and runs any tool CLI by name. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **SARIF Exporter** — `addons/sarif_export`: convert tool reports to SARIF 2.1.0 for code-scanning views. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **JUnit Exporter** — `addons/junit_export`: convert any tool report to JUnit XML for CI test views. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Static HTML Dashboard** — `addons/html_dashboard`: one offline HTML page summarizing every report in a folder. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Report Diff** — `addons/report_diff`: new, fixed and unchanged findings between two runs of a report. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Finding Suppression Baseline** — `addons/suppressions`: accepted findings with written justification, applied to reports. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Pre-commit Hook Installer** — `addons/precommit`: opt-in git hook that runs chosen CLIs on staged files. Headless suite and CLI gate pass on Godot 4.3 and 4.5; dock driven in a real editor session (`tests/editor`).
- [x] **Reusable CI Action** — `.github/actions/godot-dev-tools`: composite action that downloads Godot, imports the project and runs dispatcher commands; exercised on every PR by the `action-smoke` CI job.
- [x] **Native Accelerator Crate (research)** — research note in `docs/native-accelerator.md` (complete): measured GDScript hot paths; decision recorded not to build a native crate yet, since no tool may depend on native code and the measured scans are within budget (see `docs/performance.md`). Revisit only if a scan exceeds budget on a real project.
