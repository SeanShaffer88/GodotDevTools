# GodotDevTools

[![Tests](https://github.com/SeanShaffer88/GodotDevTools/actions/workflows/tests.yml/badge.svg)](https://github.com/SeanShaffer88/GodotDevTools/actions/workflows/tests.yml)

Independent Godot 4 addons cover testing, performance, content, workflow and release checks. The table below links each addon to its purpose and folder. Many tools are static analyzers, simulations or estimates rather than runtime measurements; consult each addon README for its scope and limitations.

The [roadmap](ROADMAP.md) tracks 110 entries, and all of them are checked. Each tool has a core, an editor dock, a headless CLI, a fixture, a test suite and a CLI gate. Each dock passes a real-editor session and each runtime node passes a live game session, and both sessions run in CI. The native-accelerator entry is a research note that ends in a recorded decision not to build. See [QUALITY.md](QUALITY.md) for the evidence.

Shared, optional components consume tool reports without any tool depending on them: the [Report Schema](addons/report_schema/README.md), [SARIF](addons/sarif_export/README.md) and [JUnit](addons/junit_export/README.md) exporters, the [HTML dashboard](addons/html_dashboard/README.md), [Report Diff](addons/report_diff/README.md), the [Finding Suppression Baseline](addons/suppressions/README.md), the [Suite CLI Dispatcher](addons/suite_dispatcher/README.md), the [pre-commit hook installer](addons/precommit/README.md) and a [reusable CI action](.github/actions/godot-dev-tools/README.md).

## TL;DR

Think of this as a workshop wall for a Godot project. Each tool is a separate instrument that hangs on the same wall: you can take down just one and use it in your own game project, or hang them all. Each one looks at your game the way a careful tester would - comparing pictures against approved ones, replaying the exact buttons that caused a bug, trying your menus on phone screens, weighing your textures, walking your dialogue, shaking your network, searching your scenes in plain words, flagging accessibility issues for human review, checking your export settings before release day, estimating draw-call breakers, migrating your old saves, mapping your collision layers, solving your animation rigs, mixing your audio on paper, hunting your leaks, laying out your input bindings, reading your shaders, spying on your signals, checking translation coverage, tracing your behaviour trees, orchestrating your cameras, replaying your seeds, snapping your blockouts, mocking your filesystems, generating your tile rules, running your tests headless, estimating your thermal load, guarding your prefab instances, and documenting your code. Each tool also has a headless CLI; available checks and gate options vary.

AI assistants working in this repo should start at [AI_USAGE.md](AI_USAGE.md): a pasteable project prompt plus the exact file map, inspection order, and full CLI reference with defaults and exit codes.

## The tools

| Tool | What it does | Addon folder |
|---|---|---|
| Visual Regression Testing | Capture scene screenshots across resolutions and compare them with approved baselines, highlighting pixel-level differences. | `addons/visual_regression` |
| Game-State Time Machine | Record inputs and key state snapshots so you can rewind a bug, inspect variables, and replay the exact sequence that caused it. | `addons/time_machine` |
| Responsive UI Previewer | Preview a UI across common screen sizes, aspect ratios, safe areas, and stretch settings directly inside the editor. | `addons/responsive_ui` |
| Asset Health Dashboard | Find oversized textures, duplicate files, unused resources, import-setting inconsistencies, and assets that may hurt loading times. | `addons/asset_health` |
| Interactive Dialogue and Quest Debugger | Show dialogue branches and quest dependencies as a graph, then simulate choices and inspect which conditions activate. | `addons/dialogue_quest` |
| Multiplayer Network Simulator | Add configurable latency, packet loss, and disconnects to local multiplayer testing, with tools to inspect synchronisation issues. | `addons/network_sim` |
| Natural-Language Scene Search | Search project content with queries like "find enemies that use a patrol state" or "show scenes with a door interaction", using project metadata and code indexing. | `addons/scene_search` |
| Automated Accessibility Checker | Detect tiny text, low contrast, missing keyboard navigation, and controls that rely only on colour. | `addons/accessibility` |
| Build and Export Doctor | Diagnose export failures and configuration mistakes, explain likely causes, and suggest targeted fixes before a release build. | `addons/export_doctor` |
| Draw Call and Batching Profiler | Find 2D draw-call breakers in scene text: material switches, z-index interleaving and per-light render passes. Estimates, confirmed against the live profiler monitors. | `addons/batch_profiler` |
| Hot-Reloadable Schema and Save-Game Migrator | Version saves and migrate them forward through registered rename/move/default/delete steps; the registry re-reads from disk every run. | `addons/schema_migrator` |
| Physics Collision Matrix Visualizer | Build the who-collides-with-whom matrix from layer names and scene masks; flag all-vs-all bodies and redundant raycast layers; count real contacts in play. | `addons/collision_matrix` |
| Procedural Animation Rigging Helper | Two-bone IK, FABRIK, look-at, squash-and-stretch and foot-placement solvers (2D), validated from a rig config and drivable from a live rig node. | `addons/proc_anim` |
| Audio Bus and Dynamic Mixing Sandbox | Simulate ducking, reverb zones and voice budgets from pure data on a 10 ms clock; catch ducking loops, missing buses and stuck zones before shipping. | `addons/audio_sandbox` |
| Memory Leak and Orphan Node Hunter | Static scan for remove_child-without-free, RefCounted reference circles and signal holds; the runtime watcher proves which detached nodes never free. | `addons/leak_hunter` |
| Multi-Platform Input Matrix and Rebinding Suite | Action-by-device matrix from the live InputMap or JSON: binding collisions, gamepad coverage gaps, generated remap-menu data, in-game rebinding with user:// saves. | `addons/input_matrix` |
| Shader Doctor | Static analysis of .gdshader files: redundant texture fetches, fetches in loops, branch density, dead uniforms - each with a concrete mobile-friendly rewrite. | `addons/shader_doctor` |
| Signal Flow and Event Bus Spy | Record signal sessions in game, then analyze: emitter-to-listener latency, dropped emissions, cascade depth, recursion and runaway emitters. | `addons/signal_spy` |
| Localization Matrix and In-Context Previewer | Key-by-locale completeness from CSV/PO tables, overflow-risk lengths, plural-rule checks, orphan tr() keys. Preview data, no network, no machine translation. | `addons/l10n_matrix` |
| Behaviour Tree and State Machine Debugger | Validate and run JSON behaviour definitions (selector/sequence trees, guarded transitions, blackboards) with a full decision trace; the runtime agent shares the interpreter. | `addons/bt_debugger` |
| Camera Shake, Transition and Framing Orchestrator | Seeded deterministic shake, ease-curve transitions and deadzone framing maths with config validation; the runtime rig applies the same functions to a live Camera2D. | `addons/camera_orch` |
| Deterministic Seed and Replay Runner | Record seed, PRNG consumption and event hash chains in game; verify a log by replaying a hand-rolled LCG to pinpoint the first divergence of a determinism bug. | `addons/seed_replay` |
| Level Whiteboxing and Snapping Suite | Grid/rotation snapping and slope maths, plus a headless scene audit for off-grid blockout props and ramps steeper than the controller can climb. | `addons/whitebox` |
| Cross-Platform Virtual Filesystem Mock | Resolve file operations against linux/windows/android/ios rules (case, sandbox, read-only roots, reserved names, length) and audit scripts for platform-isms. | `addons/vfs_mock` |
| Tilemap Rule and Autotile Generator | Validate Godot 4 terrain peering rule sets (asymmetric edges, missing transitions, corner conflicts) and generate the transition tile specs they need. | `addons/tilemap_rules` |
| CI and Headless Test Runner | Discover and classify test files (harness or GUT, detected not depended on), plan headless commands, JUnit XML out, --check-only triage into errors vs warnings. | `addons/test_runner` |
| Mobile Thermal and Battery Drain Emulation Dock | Documented-estimate RC thermal model: time-to-throttle, frame-budget misses and battery hours, for comparing workload changes on the same guessed hardware. | `addons/thermal_sim` |
| Smart Prefab and Variant Instance Manager | Classify prefab instance overrides (dead vs hiding), generate rollback plans, and write only with an explicit --apply. | `addons/prefab_guard` |
| Automated Documentation Generator for GDScript | Parse ## doc comments, signals, exports and functions into Markdown and dependency-free HTML; report undocumented public API. | `addons/doc_gen` |
| Scene Dependency Map | Browse static references and preview change impact or rename candidates; flag missing links, cycles, long chains and potentially unused assets. | `addons/scene_dependency` |
| Demo-to-Release Content Guard | Review explicit development and placeholder markers before release. | `addons/release_guard` |
| Naming and Folder Convention Enforcer | Audit file, folder, node, signal and literal group names with configurable patterns. | `addons/naming_conventions` |
| Subtitle Timing and Readability Auditor | Check JSON, SRT and WebVTT timing and readability heuristics. | `addons/subtitle_audit` |
| Player Telemetry Schema Validator | Check local synthetic event samples against explicit field and sensitivity rules. | `addons/telemetry_schema` |
| Performance Regression Gate | Compare benchmark measurements to baselines with noise tolerances. | `addons/performance_gate` |
| Feature Flag and Rollout Simulator | Simulate offline rollouts, prerequisites and fallback defaults. | `addons/flag_simulator` |
| Build Size Attribution Explorer | Inventory staged-build file sizes and budgets; archives remain opaque. | `addons/build_size` |
| Platform Certification Checklist Runner | Compare user-defined requirements to recorded reviews; does not certify compliance. | `addons/cert_check` |
| State Transition Coverage Tracker | Compare recorded transitions to a model; includes opt-in bounded runtime recording. | `addons/state_coverage` |
| Regression Test Prioritizer | Rank tests using explicit mappings and an optional static dependency graph. | `addons/test_priority` |
| Particle Budget Inspector | Total particle capacity per scene (amount x amount_ratio, instanced children followed) against scene, emitter, CPU and preprocess budgets. | `addons/particle_budget` |
| Object Pool Advisor | Rank instantiate() sites as pool candidates (per-frame, repeating, looped, self-freeing); optional recorded spawn counts from a runtime counter. | `addons/pool_advisor` |
| Node Path Breakage Detector | Resolve `$Path`, `get_node("...")` and `%Unique` strings against every scene tree that uses the script, following instanced scenes. | `addons/node_paths` |
| Unused Signal and Method Finder | Find signals never emitted or connected and functions referenced nowhere in scripts or scene connections. | `addons/unused_symbols` |
| Typed GDScript Coverage Meter | Share of variables, parameters and return values with static types, per file and project, with a minimum-percentage gate. | `addons/type_coverage` |
| Script Complexity Reporter | Per-function branch complexity, length and nesting depth with configurable thresholds. | `addons/script_complexity` |
| Duplicate Code Detector | Normalized line-window clone detection across GDScript files, merged into the longest repeated blocks. | `addons/duplicate_code` |
| Export Variable Range Auditor | Scene-stored and default values of `@export_range` properties checked against their limits (honouring or_greater/or_less); optional list of unhinted numeric exports. | `addons/export_ranges` |
| Autoload Dependency Graph | Autoload-to-autoload references from project settings and scripts: cycles, missing scripts, and `_init`/`_enter_tree`/`_ready` use of autoloads declared later. | `addons/autoload_graph` |
| Resource UID Integrity Checker | `uid://` references in ext_resources and scripts checked against declared UIDs (scene/resource headers, .import and .uid files): stale, duplicate and unknown UIDs. | `addons/uid_integrity` |
| Project Settings Drift Report | Key-by-key diff of `project.godot` against a committed baseline, with ignore patterns. | `addons/settings_drift` |
| Scene Lint Rule Engine | User-defined JSON rules over scene text: required child types, forbidden/required properties, node-name patterns; physics bodies need shapes by default. | `addons/scene_lint` |
| Loot Table and Economy Simulator | Seeded weighted-table simulation: per-item odds, expected value per open, observed rates and 99th-percentile drought lengths. | `addons/loot_sim` |
| Difficulty Curve Analyzer | Enemy-to-player power ratio per level from a data table; flags spikes, dips and ratios beyond a ceiling. | `addons/difficulty_curve` |
| Damage Formula Sandbox | Evaluates a formula over a stat grid with Godot's Expression class; flags negative, overflowing, non-finite and non-monotonic results. | `addons/damage_sandbox` |
| XP Curve Planner | Minutes per level from an XP table (or formula) and earn rates by level band; flags grind walls and shrinking requirements. | `addons/xp_curve` |
| Crafting and Inventory Graph Validator | Fixpoint reachability over recipes from base items: unobtainable goals, missing inputs, self-bootstrapping recipes, dead-end items. | `addons/crafting_graph` |
| Achievement Reachability Checker | Unlock conditions checked against declared events and capped stats; unknown references, unreachable thresholds, cycles and blocked meta-achievements. | `addons/achievements` |
| Wave Spawner Budget Planner | Timeline simulation of wave spawn groups: peak enemies alive, spawns per second, overruns past wave duration. | `addons/wave_budget` |
| Random Table Fairness Tester | Pearson chi-square goodness of fit of recorded outcome counts against intended weights, with p-values and small-sample warnings. | `addons/rng_fairness` |
| Save File Bloat Auditor | JSON save size by key path, dominant keys, growth across ordered sample saves, total-size budget. | `addons/save_bloat` |
| Dialogue Variable Lint | Dialogue condition reads versus effect writes in dialogue JSON; read-never-set, set-never-read and type mismatches, with an external-variable allow list. | `addons/dialogue_vars` |
| Font Glyph Coverage Checker | Characters used per locale in translation CSV/PO files checked against a TTF/OTF cmap table (formats 4 and 12). | `addons/font_glyphs` |
| Audio Loudness and Clipping Auditor | WAV peak/RMS dBFS, clipped samples, DC offset and sample-rate outliers from the PCM data itself. | `addons/audio_levels` |
| Audio Import Settings Auditor | Audio `.import` loop and compression settings against clip role (music/sfx folder patterns) and WAV length. | `addons/audio_import` |
| Texture Atlas Packing Planner | Shelf-packs sprite sizes (from PNG headers or a JSON list) into atlas pages; page count, waste, oversize sprites. | `addons/atlas_planner` |
| Texture Filter Consistency Checker | Pixel-art texture imports (by folder pattern) checked for mipmaps and lossy compression, plus the project default canvas filter. | `addons/texture_filter` |
| Mesh Statistics Report | Triangles, vertices, primitives and materials per glTF/GLB file from accessor counts, against budgets. | `addons/mesh_stats` |
| 3D Light and Shadow Cost Estimator | Omni, spot and directional lights per scene (instanced scenes followed), shadow casters, against budgets and renderer limits. | `addons/light_cost` |
| Environment Feature Cost Matrix | Environment features enabled per scene/resource (SDFGI, SSR, SSAO, SSIL, volumetric fog, glow...) with relative cost tiers and Compatibility-renderer support. | `addons/env_cost` |
| Colour Palette Consistency Checker | Colour literals in scenes, resources and scripts compared with an approved palette by CIE76 delta E. | `addons/palette_check` |
| Theme Resource Auditor | Theme override counts per scene, distinct and near-duplicate font sizes, and theme type variations no scene uses. | `addons/theme_audit` |
| Flaky Test Detector | Test-run histories (JUnit XML folders or JSON): same-commit pass/fail flips, flip rates and always-failing tests. | `addons/flaky_tests` |
| Golden Data Snapshot Tester | JSON outputs compared with approved goldens by JSON path (changed, added, removed, type changes) with a float tolerance. | `addons/golden_snapshot` |
| Error Log Grouper | Godot log errors and warnings grouped by normalized signature (numbers and quoted names masked) with counts and first location. | `addons/log_grouper` |
| Log Warning Budget Gate | Error/warning counts and new message signatures in a captured log against a committed baseline. | `addons/log_budget` |
| State Trace Determinism Diff | Two recorded per-frame state traces compared key by key; first divergent frame, diverging keys, length mismatch. | `addons/trace_diff` |
| Input Sequence Fuzzer | Seeded, bounded press/hold/release sequences generated from the InputMap; a runtime node replays them frame by frame. | `addons/input_fuzzer` |
| GDScript Warning Baseline | Static per-file counts of UNUSED_VARIABLE, UNUSED_PARAMETER and UNREACHABLE_CODE patterns, ratcheted against a committed baseline. | `addons/warning_baseline` |
| Scene Load Smoke Tester | Loads and instantiates every scene headless; load/instantiate failures, missing dependencies, unknown node types. | `addons/scene_smoke` |
| Micro-Benchmark Harness | Times `bench_*` methods with warm-up and repetitions; median, p95, spread; output is Performance Regression Gate input. | `addons/bench_harness` |
| GDScript Mutation Tester | Operator mutants of one script, each run against its test in an isolated temporary project; surviving mutants show untested behaviour. | `addons/mutation_tester` |
| Store Asset Validator | Store images (PNG/JPEG headers) against a user-written profile: missing files, wrong sizes, screenshot counts. | `addons/store_assets` |
| Android Permissions Reviewer | Permissions requested by each Android export preset; sensitive ones flagged for review, optional justification file. | `addons/android_permissions` |
| Version Consistency Checker | Project `config/version` against version strings in export presets (Android, Windows, macOS, iOS, web). | `addons/version_consistency` |
| Third-Party Notice Collector | License files gathered per addon/vendor folder into a notices report; missing licenses and copyleft licenses flagged for review. | `addons/third_party_notices` |
| Release Notes Generator | Conventional-commit subjects grouped into draft release notes (breaking, added, fixed, performance, other). | `addons/release_notes` |
| Content Descriptor Checklist | User-defined content questionnaire with recorded answers: unanswered, invalid, missing evidence, stale reviews. No rating claim. | `addons/content_descriptor` |
| Patch Delta Estimator | Two staged builds compared file by file (MD5): added, removed and changed bytes, monolithic pack warnings, delta budget. | `addons/patch_delta` |
| Settings File Validator | Player settings files (ConfigFile or JSON) against a schema: unknown keys, wrong types, out-of-range and disallowed values. | `addons/settings_validator` |
| Accessibility Options Coverage | Keyword evidence in scripts, scenes and data that expected accessibility options exist (subtitles, remapping, text size, colour-blind modes, reduced motion, mono audio, hold/toggle). | `addons/a11y_options` |
| Handheld Readiness Checklist | Stretch mode, text size scaled to a target screen height, actions without gamepad bindings, and buttons that cannot take focus. | `addons/handheld_readiness` |
| Report Schema | Documented JSON Schema for tool reports (summary + issues with severity/kind/message) and a validator for report folders. | `addons/report_schema` |
| SARIF Exporter | Converts every tool report in a folder into one SARIF 2.1.0 log (one run per tool) for code-scanning views. | `addons/sarif_export` |
| JUnit Exporter | Converts tool reports into JUnit XML: one suite per tool, one test case per finding kind, failures carrying each finding. | `addons/junit_export` |
| Static HTML Dashboard | One self-contained offline HTML page: per-tool counts by severity and every finding, filterable, light and dark. | `addons/html_dashboard` |
| Report Diff | Two report folders compared: new, fixed and unchanged findings, matched by tool, kind, path and message so moved lines still match. | `addons/report_diff` |
| Finding Suppression Baseline | Accepted findings with written justifications and expiry dates applied to a reports folder; remaining findings re-emitted for gating. | `addons/suppressions` |
| Suite CLI Dispatcher | Lists every installed tool CLI and runs any of them by name (or all with defaults) in a child process, passing options and exit codes through. | `addons/suite_dispatcher` |
| Pre-commit Hook Installer | Generates an opt-in git pre-commit hook running chosen tool CLIs; installs or removes only hooks it wrote. | `addons/precommit` |
| Shader Variant Budget Manager | Distinct BaseMaterial3D feature combinations (each a separate generated shader) plus #ifdef combinations in .gdshader files, against a budget. | `addons/shader_variants` |
| LOD and Visibility Range Planner | Invalid visibility ranges, heavy instanced glTF/GLB meshes without visibility ranges, and imports with LOD generation off. | `addons/lod_planner` |
| Animation Performance Auditor | Animation resources in scenes and .tres: constant tracks, redundant interior keys, duplicate-time keys, track budgets. | `addons/anim_audit` |
| Rendering Settings Compatibility Matrix | Rendering nodes and environment features used per scene against a renderer support matrix (built-in Compatibility list, overridable JSON). | `addons/render_compat` |
| GPU Budget and Overdraw Analyzer | 2D overdraw estimate per scene (sprite/rect areas clipped to the screen) and fill-rate at target resolutions and frame rates. | `addons/overdraw` |
| Frame-Time Spike Investigator | Spikes in recorded per-frame timings correlated with markers, node-count jumps and physics time; runtime recorder node included. | `addons/frame_spikes` |
| Startup and Scene-Load Profiler | Measured load and instantiate time per scene (cache bypassed), dependency and node counts, against budgets. | `addons/load_profiler` |
| Physics Jitter and Tunneling Detector | Small rigid bodies without CCD, scripts writing rigid-body transforms, move_and_slide in _process, low physics tick rate. | `addons/physics_jitter` |
| Character Controller Test Course | Platformer tuning (gravity, jump velocity, speed, coyote time, floor angle) against course obstacles via kinematics: unreachable ledges, unjumpable gaps, too-steep slopes. | `addons/controller_course` |
| Hitbox and Hurtbox Timeline Viewer | Active windows of hitbox/hurtbox shapes from animation `disabled`/`monitoring` tracks; windows left open, shorter than a physics frame, and invulnerability windows. | `addons/hitbox_timeline` |
| Navigation Mesh Diagnostic Lab | Baked NavigationPolygon analysis: disconnected regions, passages narrower than the agent, unreachable and off-mesh targets. | `addons/navmesh_lab` |
| Spawn Point and Encounter Validator | 2D spawn markers (group or name) checked against static collision shapes, minimum spacing and an optional navmesh. | `addons/spawn_validator` |
| Interaction Reachability Checker | Interactable trigger areas (group or name) checked against navmesh reachable from the player start. | `addons/interaction_reach` |
| World Boundary and Out-of-Bounds Auditor | 2D level extents from static collision: missing kill floor/world boundary below, open sides, kill zones overlapping floors. | `addons/world_bounds` |
| AI Perception Debugger | 2D sight (range, field of view, wall occlusion) and hearing (range x noise, walls muffle) per agent-target pair with a decision trace and expectations. | `addons/ai_perception` |
| Gameplay Ability Simulator | Priority-rotation simulation of abilities with costs, cooldowns, cast times and regenerating resources: casts, DPS, idle and wasted resource time. | `addons/ability_sim` |
| Procedural Generation Constraint Tester | Generated text-grid maps checked by flood fill: reachable exit, key before door, isolated floor pockets, dead-end share; failure rate across seeds. | `addons/procgen_constraints` |
| Controller Glyph and Prompt Validator | Action tokens in prompt text checked against the InputMap, per-device bindings, and glyph images in per-device folders. | `addons/controller_glyphs` |
| Color-Vision and Contrast Previewer | Palette colours simulated for protanopia, deuteranopia and tritanopia (Machado 2009, full severity); pairs below a delta E threshold flagged, simulated colours listed. | `addons/colorvision` |
| Scene Merge Conflict Assistant | Git conflict hunks in scene/resource/project text explained by section, node and property (property clashes, ext_resource id collisions, load_steps); read-only. | `addons/merge_conflicts` |
| Project Cleanup Workbench | Review list of unreferenced assets, duplicate files (MD5), stale .import/.uid sidecars and empty folders; never deletes. | `addons/cleanup_workbench` |
| Scene Review Snapshot Generator | Reproducible scene inventory (nodes, types, scripts, instances, stored properties) as JSON, and a node/property diff against another version. | `addons/scene_snapshot` |
| Node Property Drift Monitor | Per node type and property, the dominant stored value across scenes; outliers drifting from it, or deviations from a committed baseline. | `addons/property_drift` |
| Art-to-Engine Handoff Validator | glTF/GLB handoff checks: unapplied node scale, implausible bounds, default material/animation names, missing UVs for textured materials, unknown -col style suffixes. | `addons/art_handoff` |
| Gameplay Scenario Test Builder | JSON gameplay scenarios (wait, press/release actions, call, set, assert) run headless against an instanced scene, one step per physics frame. | `addons/scenario_tests` |
| Crash and Error Reproduction Packager | Local bug-report bundle: redacted log (emails, IPs, tokens, user paths), engine/OS details, repro steps and a manifest, optionally zipped. Never uploads. | `addons/crash_packager` |
| Save Corruption and Recovery Tester | Corrupted variants of a sample JSON save (truncated, empty, wrong root, wrong types, missing keys, extreme numbers) fed to your loader; accepted-invalid and no-fallback cases reported. | `addons/save_corruption` |
| Property-Based Gameplay Tester | Seeded random and edge inputs for pure static functions, properties as expressions, failures shrunk to minimal counterexamples. | `addons/property_tests` |
| Resource Load Failure Simulator | Runtime `load()` results used without null checks, chained `load().instantiate()`, missing literal paths, threaded loads without status checks. | `addons/load_failure` |
| Pause, Focus, and Lifecycle Tester | Effective process mode per scripted node while paused (pause menus that freeze themselves, gameplay that keeps running), missing focus/suspend handling, wall-clock timing. | `addons/lifecycle` |
| Privacy and Permissions Auditor | Inventory of network endpoints and APIs, device identifiers, clipboard, microphone/camera use and external links, for a privacy review. | `addons/privacy_audit` |
| Offline and Poor-Connection Test Harness | Static: HTTP requests without timeouts and completion handlers that ignore result codes. Runtime: drop-in HTTP node applying seeded offline/timeout/slow/error faults. | `addons/offline_harness` |
| Editor Action Macro Recorder | Records Inspector property edits as JSON macros (node paths or selectors); previews changes on any scene; applies only with an explicit --apply. | `addons/macro_recorder` |

Each addon folder has its own README with install steps, editor use, command-line options and limits.

## Screenshots

Real captures are still to be taken on a Windows machine with the plugins enabled in a real project. Capture list:

1. The Asset Health dock after a scan of a real project.
2. The Responsive UI dock listing which screen sizes break a HUD.
3. The Dialogue and Quest dock with a branch problem list.
4. A visual-regression highlight image next to its baseline.

No placeholder images are used in the meantime.

## Requirements

- Godot **4.3** is the verified version. The headless CI gate also passed on **4.5**, which remains an experimental CI target. Other Godot versions are unverified.
- No third-party dependencies. No network access is used at any point.

## Install

For one tool: copy its `addons/<tool>` folder into your project's `addons/` folder and enable it under Project -> Project Settings -> Plugins. Check the assets on the [GitHub Releases](https://github.com/SeanShaffer88/GodotDevTools/releases) page before downloading: older releases do not contain every current addon. Unzip an addon or suite archive into your project root.

For the whole suite: copy every `addons/` folder from this checkout (or use a suite release that includes them), then enable the plugins you want. Each tool works on its own; none depends on another.

## How to use

### In the editor

Each tool adds a dock on the right side of the editor with a **Run check** button, a results list, and a `?` help button that explains the tool in plain words, offline. Four tools also add pieces beyond the check:

- **Visual Regression**: the dock's Capture section is the one-click shutter - list scene paths (empty = the main scene), press **Capture now**, and every scene is saved as `<scene>__<width>x<height>.png` in the capture folder at each standard resolution, ready for the compare run. Needs the editor's renderer; never runs headless.
- **Dialogue and Quest**: the dock draws the selected dialogue's branch graph - layered boxes with arrows for choices, `[if]` tags on conditional choices, orange for flagged nodes and a red dashed ghost box for every choice that points at a missing node.
- **Time Machine**: add `addons/time_machine/runtime/gstm_node.gd` to a scene, register Callables that return your game's state as a Dictionary and Callables that restore it, and it records every physics frame. `rewind_to(frame)` restores a snapshot; sessions save to JSON so a bug report carries its exact cause.
- **Network Simulator**: route test packets through `addons/network_sim/runtime/mns_proxy.gd` and set its latency / jitter / loss in the inspector; delivery arrives via its `message_delivered` signal.

### From the command line (CI, scripts, pre-commit)

Every tool has a headless CLI in its `cli/` folder running the same core operation as its dock, writing JSON + Markdown reports, with `--fail-on=...` gates that exit with code 2 when a listed problem is found:

```sh
godot --headless --path . --script res://addons/asset_health/cli/ahd_cli.gd -- --fail-on=duplicate,oversized_texture
godot --headless --path . --script res://addons/export_doctor/cli/bed_cli.gd -- --fail-on=errors
godot --headless --path . --script res://addons/scene_search/cli/nlss_cli.gd -- --query="find enemies that use a patrol state"
```

For authoritative options, consult each addon README and CLI script.

## Downloads

The published [v1.0.0 release](https://github.com/SeanShaffer88/GodotDevTools/releases/tag/v1.0.0) contains nine individual addon zips and a suite zip for those nine, not the current set. The [v1.2.0 release](https://github.com/SeanShaffer88/GodotDevTools/releases/tag/v1.2.0) carries all 133 addons, one zip each plus a suite zip; v1.1.0 was prepared but never published separately, and its changes ship in v1.2.0. The release workflow is configured to gate and package one zip per addon plus a suite for a future release. Dispatch on main or a `v*` tag starts the gate before packaging (`.github/workflows/release.yml`).

## Command-line reference

Most CLIs write JSON and Markdown reports and support `--out` and `--fail-on`; option support and error exit codes vary by tool. A selected finding generally exits `2`, while invalid input or I/O may exit `1` or `3`. The full, authoritative option list is in each CLI script's header comment; the main options are:

| CLI | Main options |
|---|---|
| `visual_regression/cli/vrt_cli.gd` | `--baseline=<dir>` `--current=<dir>` `--tolerance=<0-255>` `--fail-fraction=<f>` `--fail-on=visual_diff,missing_capture,missing_baseline` |
| `time_machine/cli/gstm_cli.gd` | `--session=<json>` `--fail-on=errors` |
| `responsive_ui/cli/ruip_cli.gd` | `--fail-on=issues` |
| `asset_health/cli/ahd_cli.gd` | `--big-texture=<px>` `--fail-on=oversized_texture,duplicate,unused,import_inconsistent,slow_load` |
| `dialogue_quest/cli/dqd_cli.gd` | `--file=<json>` `--simulate=<dialogue>:<pick,pick,...>` `--state=<json>` `--fail-on=issues,missing_target,bad_start` |
| `network_sim/cli/mns_cli.gd` | `--latency=<ticks>` `--jitter=<ticks>` `--loss=<0..1>` `--disconnect=<from>-<to>` `--ticks=<n>` `--fail-on=issues,packet_loss` |
| `scene_search/cli/nlss_cli.gd` | `--query="<plain words>"` |
| `accessibility/cli/a11y_cli.gd` | `--fail-on=errors,tiny_text,low_contrast,no_keyboard_focus` |
| `export_doctor/cli/bed_cli.gd` | `--fail-on=errors` |
| `batch_profiler/cli/dbp_cli.gd` | `--fail-on=errors,material_switch,z_interleave,light_pass` |
| `schema_migrator/cli/smg_cli.gd` | `--registry=<json>` `--save=<json>` `--fail-on=errors,unmigratable,missing_field,missing_file,bad_json` |
| `collision_matrix/cli/cmv_cli.gd` | `--fail-on=errors,all_vs_all,redundant_raycast_layer,unused_layer,dead_mask` |
| `proc_anim/cli/par_cli.gd` | `--config=<json>` `--fail-on=errors,solver_error,missing_file` |
| `audio_sandbox/cli/aud_cli.gd` | `--config=<json>` `--fail-on=errors,duck_loop,missing_bus,zone_stuck,missing_file` |
| `leak_hunter/cli/mlh_cli.gd` | `--fail-on=errors,refcount_cycle,orphan_risk,signal_hold` |
| `input_matrix/cli/imx_cli.gd` | `--from=<json>` (default: live InputMap) `--fail-on=errors,binding_collision,no_gamepad,missing_file` |
| `shader_doctor/cli/shd_cli.gd` | `--fail-on=errors,redundant_fetch,fetch_in_loop,unused_uniform,branch_heavy,fetch_heavy` |
| `signal_spy/cli/sgs_cli.gd` | `--session=<json>` `--fail-on=errors,runaway,recursive_signal,orphan_handle,out_of_order,deep_cascade,missing_file,bad_json` |
| `l10n_matrix/cli/lmx_cli.gd` | `--fail-on=errors,missing_translation,untranslated_call,plural_mismatch,length_risk` |
| `bt_debugger/cli/btd_cli.gd` | `--def=<json>` `--fail-on=errors,missing_state,unreachable_state,no_entry,runaway_machine,missing_file,bad_json` |
| `camera_orch/cli/cor_cli.gd` | `--config=<json>` `--fail-on=errors,config_error,missing_file` |
| `seed_replay/cli/sdr_cli.gd` | `--log=<json>` `--fail-on=errors,mismatch,chain_break` |
| `whitebox/cli/wbx_cli.gd` | `--scene=<tscn>` `--grid=<json>` `--fail-on=errors,off_grid,steep_slope,missing_file` |
| `vfs_mock/cli/vfm_cli.gd` | `--requests=<json>` (default: self-check the real tree) `--fail-on=errors,case_collision,case_mismatch,sandbox_escape,permission_denied,reserved_name,forbidden_char,too_long,path_traversal,backslash_path,drive_letter` |
| `tilemap_rules/cli/tmr_cli.gd` | `--config=<json>` `--fail-on=errors,asymmetric_rule,missing_transition,corner_conflict` |
| `test_runner/cli/ctr_cli.gd` | `--dirs=<a,b>` `--check` `--junit=<xml>` `--fail-on=errors,no_tests_found,no_finish,script_error,unclassified` |
| `thermal_sim/cli/thm_cli.gd` | `--workload=<json>` `--fail-on=errors,config_error,thermal_throttle,battery_drain_high,frame_budget_exceeded,missing_file` |
| `prefab_guard/cli/pfg_cli.gd` | `--scene=<tscn>` `--apply` (writes rollback ops) `--fail-on=errors,drifted_property,default_drift,prefab_missing,missing_file` |
| `doc_gen/cli/dcg_cli.gd` | writes `api.md` + `api.html` next to the report `--fail-on=errors,undocumented` |
| `scene_dependency/cli/sdm_cli.gd` | `--dir`, repeatable `--root`, `--impact`, `--rename-to`, `--fail-on` |
| `release_guard/cli/rg_cli.gd` | `--dir` `--rules` `--fail-on` |
| `naming_conventions/cli/nc_cli.gd` | `--dir` `--pattern` `--symbols` `--node-pattern` `--signal-pattern` `--group-pattern` `--fail-on` |
| `subtitle_audit/cli/sub_cli.gd` | `--input` `--require-speaker` `--fail-on` |
| `telemetry_schema/cli/tel_cli.gd` | `--schema` `--samples` `--fail-on` |
| `performance_gate/cli/perf_cli.gd` | `--baseline` `--current` `--fail-on` |
| `flag_simulator/cli/flag_cli.gd` | `--config` `--subject` `--unavailable` `--fail-on` |
| `build_size/cli/bs_cli.gd` | `--dir` `--max-file` `--max-total` `--fail-on` |
| `cert_check/cli/cert_cli.gd` | `--first` `--second` `--fail-on` |
| `state_coverage/cli/coverage_cli.gd` | `--first` `--second` `--check-continuity` `--fail-on` |
| `test_priority/cli/priority_cli.gd` | `--first` `--second` `--graph` `--fail-on` |

## This repo's layout

```
addons/<tool>/            one folder per tool, independently installable
  plugin.cfg, plugin.gd   editor entry point
  core/                   the check itself (no editor APIs)
  ui/                     the editor dock
  cli/                    the headless command-line runner
  runtime/                (time_machine, network_sim, collision_matrix, proc_anim, leak_hunter, input_matrix, signal_spy, bt_debugger, camera_orch, seed_replay, state_coverage) in-game nodes
demo/                     a fixture project with a deliberate problem per tool
tests/                    one suite per tool + run_tests.sh, the full gate
docs/PARITY.md            capability matrix, scored from test evidence
QUALITY.md                quality scorecard
PROJECT_RULES.md          project rule sheet
AI_USAGE.md               AI-agent guide: pasteable prompt + exact tool/CLI map
```
| `particle_budget/cli/pbi_cli.gd` | `--dir` `--max-scene` `--max-emitter` `--max-cpu-emitter` `--max-preprocess` `--fail-on` |
| `pool_advisor/cli/opa_cli.gd` | `--dir` `--counts` `--min-score` `--rate-threshold` `--fail-on` |
| `node_paths/cli/npb_cli.gd` | `--dir` `--report-unattached` `--fail-on` |
| `unused_symbols/cli/usf_cli.gd` | `--dir` `--include-private` `--fail-on` |
| `type_coverage/cli/tcm_cli.gd` | `--dir` `--min-percent` `--fail-on` |
| `script_complexity/cli/scx_cli.gd` | `--dir` `--max-complexity` `--max-lines` `--max-nesting` `--fail-on` |
| `duplicate_code/cli/dup_cli.gd` | `--dir` `--min-lines` `--fail-on` |
| `export_ranges/cli/era_cli.gd` | `--dir` `--report-unhinted` `--fail-on` |
| `autoload_graph/cli/alg_cli.gd` | `--project` `--fail-on` |
| `uid_integrity/cli/uid_cli.gd` | `--dir` `--fail-on` |
| `settings_drift/cli/psd_cli.gd` | `--project` `--baseline` `--ignore` `--fail-on` |
| `scene_lint/cli/slr_cli.gd` | `--dir` `--rules` `--fail-on` |
| `loot_sim/cli/lts_cli.gd` | `--input` `--draws` `--seed` `--max-drought` `--fail-on` |
| `difficulty_curve/cli/dca_cli.gd` | `--input` `--spike` `--dip` `--max-ratio` `--fail-on` |
| `damage_sandbox/cli/dfs_cli.gd` | `--input` `--max-combinations` `--fail-on` |
| `xp_curve/cli/xpc_cli.gd` | `--input` `--wall-factor` `--fail-on` |
| `crafting_graph/cli/cgv_cli.gd` | `--input` `--fail-on` |
| `achievements/cli/ach_cli.gd` | `--input` `--fail-on` |
| `wave_budget/cli/wsb_cli.gd` | `--input` `--max-alive` `--max-spawn-rate` `--default-lifetime` `--fail-on` |
| `rng_fairness/cli/rft_cli.gd` | `--input` `--alpha` `--fail-on` |
| `save_bloat/cli/sba_cli.gd` | `--dir` `--max-bytes` `--dominant-share` `--growth-factor` `--fail-on` |
| `dialogue_vars/cli/dvl_cli.gd` | `--dir` `--external` `--fail-on` |
| `font_glyphs/cli/fgc_cli.gd` | `--font` `--strings` `--fail-on` |
| `audio_levels/cli/ala_cli.gd` | `--dir` `--expected-rate` `--quiet-db` `--max-samples` `--fail-on` |
| `audio_import/cli/aia_cli.gd` | `--dir` `--music-pattern` `--sfx-pattern` `--max-wav-seconds` `--fail-on` |
| `atlas_planner/cli/atp_cli.gd` | `--input` `--page-size` `--padding` `--max-pages` `--max-waste` `--fail-on` |
| `texture_filter/cli/tfc_cli.gd` | `--dir` `--pixel-pattern` `--project` `--fail-on` |
| `mesh_stats/cli/msr_cli.gd` | `--dir` `--max-triangles` `--max-materials` `--fail-on` |
| `light_cost/cli/lsc_cli.gd` | `--dir` `--max-shadowed` `--max-lights` `--renderer` `--fail-on` |
| `env_cost/cli/ecm_cli.gd` | `--dir` `--max-cost` `--renderer` `--fail-on` |
| `palette_check/cli/pcc_cli.gd` | `--dir` `--palette` `--fail-on` |
| `theme_audit/cli/tra_cli.gd` | `--dir` `--max-overrides` `--max-font-sizes` `--fail-on` |
| `flaky_tests/cli/flk_cli.gd` | `--input` `--flip-rate` `--fail-on` |
| `golden_snapshot/cli/gst_cli.gd` | `--current` `--golden` `--tolerance` `--fail-on` |
| `log_grouper/cli/lgr_cli.gd` | `--log` `--fail-on` |
| `log_budget/cli/lbg_cli.gd` | `--log` `--baseline` `--fail-on` |
| `trace_diff/cli/sdt_cli.gd` | `--first` `--second` `--tolerance` `--fail-on` |
| `input_fuzzer/cli/isf_cli.gd` | `--project` `--seed` `--sequences` `--length` `--max-hold` `--include-ui` `--fail-on` |
| `warning_baseline/cli/gwb_cli.gd` | `--dir` `--baseline` `--fail-on` |
| `scene_smoke/cli/sst_cli.gd` | `--dir` `--fail-on` |
| `bench_harness/cli/mbh_cli.gd` | `--script` `--iterations` `--warmup` `--max-cv` `--fail-on` |
| `mutation_tester/cli/gmt_cli.gd` | `--target` `--test` `--max-mutants` `--timeout` `--fail-on` |
| `store_assets/cli/sav_cli.gd` | `--profile` `--fail-on` |
| `android_permissions/cli/apr_cli.gd` | `--presets` `--justifications` `--fail-on` |
| `version_consistency/cli/vcc_cli.gd` | `--project` `--presets` `--expected` `--fail-on` |
| `third_party_notices/cli/tpn_cli.gd` | `--dir` `--fail-on` |
| `release_notes/cli/rln_cli.gd` | `--commits` `--version` `--include-other` `--fail-on` |
| `content_descriptor/cli/cdc_cli.gd` | `--input` `--max-age-days` `--today` `--fail-on` |
| `patch_delta/cli/pde_cli.gd` | `--old` `--new` `--max-delta` `--fail-on` |
| `settings_validator/cli/ssv_cli.gd` | `--dir` `--schema` `--fail-on` |
| `a11y_options/cli/aoc_cli.gd` | `--dir` `--expect` `--fail-on` |
| `handheld_readiness/cli/hrc_cli.gd` | `--dir` `--project` `--target-height` `--min-text-px` `--fail-on` |
| `report_schema/cli/rsv_cli.gd` | `--reports` `--fail-on` |
| `sarif_export/cli/srf_cli.gd` | `--reports` `--fail-on` |
| `junit_export/cli/jux_cli.gd` | `--reports` `--fail-level` `--fail-on` |
| `html_dashboard/cli/hdb_cli.gd` | `--reports` `--title` `--fail-on` |
| `report_diff/cli/rdf_cli.gd` | `--before` `--after` `--fail-on` |
| `suppressions/cli/fsb_cli.gd` | `--reports` `--suppressions` `--today` `--fail-on` |
| `suite_dispatcher/cli/gdt_cli.gd` | `--addons` `--fail-on` |
| `precommit/cli/pch_cli.gd` | `--config` `--install` `--uninstall` `--git-dir` `--fail-on` |
| `shader_variants/cli/svb_cli.gd` | `--dir` `--max-variants` `--max-defines` `--fail-on` |
| `lod_planner/cli/lod_cli.gd` | `--dir` `--heavy-triangles` `--fail-on` |
| `anim_audit/cli/apa_cli.gd` | `--dir` `--max-tracks` `--fail-on` |
| `render_compat/cli/rcm_cli.gd` | `--dir` `--renderer` `--matrix` `--fail-on` |
| `overdraw/cli/gbo_cli.gd` | `--dir` `--width` `--height` `--max-overdraw` `--fps` `--fail-on` |
| `frame_spikes/cli/fts_cli.gd` | `--input` `--spike-factor` `--window` `--max-miss-rate` `--fail-on` |
| `load_profiler/cli/slp_cli.gd` | `--dir` `--max-load-ms` `--max-instantiate-ms` `--fail-on` |
| `physics_jitter/cli/pjt_cli.gd` | `--dir` `--project` `--min-size` `--fail-on` |
| `controller_course/cli/cct_cli.gd` | `--input` `--margin` `--fail-on` |
| `hitbox_timeline/cli/hht_cli.gd` | `--dir` `--physics-fps` `--hurt-pattern` `--fail-on` |
| `navmesh_lab/cli/nml_cli.gd` | `--nav` `--targets` `--fail-on` |
| `spawn_validator/cli/spv_cli.gd` | `--scene` `--min-spacing` `--spawn-pattern` `--nav` `--fail-on` |
| `interaction_reach/cli/irc_cli.gd` | `--scene` `--nav` `--start` `--pattern` `--fail-on` |
| `world_bounds/cli/wba_cli.gd` | `--scene` `--kill-pattern` `--fail-on` |
| `ai_perception/cli/aip_cli.gd` | `--input` `--wall-muffle` `--fail-on` |
| `ability_sim/cli/gas_cli.gd` | `--input` `--step` `--max-idle` `--fail-on` |
| `procgen_constraints/cli/pgc_cli.gd` | `--dir` `--max-dead-end-ratio` `--fail-on` |
| `controller_glyphs/cli/cgp_cli.gd` | `--dir` `--glyphs` `--project` `--token` `--fail-on` |
| `colorvision/cli/cvp_cli.gd` | `--input` `--fail-on` |
| `merge_conflicts/cli/smc_cli.gd` | `--dir` `--fail-on` |
| `cleanup_workbench/cli/pcw_cli.gd` | `--dir` `--root` `--fail-on` |
| `scene_snapshot/cli/ssg_cli.gd` | `--scene` `--compare` `--fail-on` |
| `property_drift/cli/npd_cli.gd` | `--dir` `--baseline` `--min-nodes` `--majority` `--fail-on` |
| `art_handoff/cli/aeh_cli.gd` | `--dir` `--min-size` `--max-size` `--fail-on` |
| `scenario_tests/cli/gsb_cli.gd` | `--scenario` `--fail-on` |
| `crash_packager/cli/crp_cli.gd` | `--log` `--steps` `--zip` `--max-log-bytes` `--fail-on` |
| `save_corruption/cli/scr_cli.gd` | `--save` `--loader` `--allow-null` `--fail-on` |
| `property_tests/cli/pbt_cli.gd` | `--input` `--runs` `--fail-on` |
| `load_failure/cli/rlf_cli.gd` | `--dir` `--fail-on` |
| `lifecycle/cli/pfl_cli.gd` | `--dir` `--fail-on` |
| `privacy_audit/cli/ppa_cli.gd` | `--dir` `--fail-on` |
| `offline_harness/cli/ocn_cli.gd` | `--dir` `--profile` `--fail-on` |
| `macro_recorder/cli/eam_cli.gd` | `--macro` `--scene` `--apply` `--fail-on` |

The root of this repo is itself a Godot project: open it, enable the plugins, and run any dock against the `demo/` fixture, which deliberately contains a changed screenshot pair, a rewindable session, an overflowing HUD with tiny low-contrast text and a keyboard-unreachable button, a 3000x2000 texture, a duplicated and an unused asset, inconsistent import settings, a dialogue with a missing branch target and an unreachable room, quests with a missing requirement and a dependency circle, a patrol enemy and a door interaction to search for, an export preset pointing at an icon that does not exist, and one deliberate problem per new tool: an interleaved market scene, a save no registered path can migrate, an all-vs-all collision body, a rig chain that cannot reach its target, a mix layout with a ducking loop, scripts that orphan nodes and circle references, Space bound to two actions, a shader that double-fetches, a signal session with a runaway emitter, a missing translation with a wrong plural rule, a behaviour transition to a state nobody defines, a camera config naming an ease that does not exist, a seed log with one tampered PRNG value, a blockout crate off the grid and a ramp too steep to climb, two files one letter-case apart, a tilemap rule that runs one way only, a test file that never quits, a workload that throttles a low-end estimate, a prefab instance carrying a dead override, and a script with undocumented public API.

## Dialogue and quest data format

The Dialogue and Quest Debugger reads JSON files with `dialogues` and/or `quests` objects: dialogue nodes carry `speaker`, `text`, `choices` (each with `text`, `next`, an optional `condition` of `{var, op, value}` and optional `effects`), a plain `next` for linear flow, or `"end": true`. Quests carry `title` and `requires` (quest ids). See `demo/dialogue/story.json` for a complete example.

## Tests

```sh
sh tests/run_tests.sh /path/to/godot
```

The gate imports the project, runs the per-tool suites (checks counted in QUALITY.md), and exercises the CLIs including the exit-code-2 CI gates on the fixture. The same gate runs automatically on pushes to main and pull requests (`.github/workflows/tests.yml`) on Godot 4.3-stable - the verified version - and on 4.5-stable as experimental evidence. Current status: see `QUALITY.md`.

## Troubleshooting

- **A dock is empty or missing.** Project -> Project Settings -> Plugins: make sure that tool's plugin is enabled, then press its **Run check** button.
- **Scene Search finds nothing.** It matches the words in file names, node names, functions, variables and content - not synonyms. Search with the words your project actually uses.
- **Asset Health flags a file you load at run time as unused.** Its path is probably built from pieces at run time. Treat the flag as a prompt to check, not proof.
- **Accessibility contrast looks wrong for a light theme.** Contrast is measured against a dark background by default; set `assumed_background` in the checker core to your game's real background colour.

## Privacy and network behaviour

Everything runs locally, in the editor or a headless Godot process. The tools read your project files and write only the reports you ask for, into your project. Nothing is uploaded, tracked, or sent anywhere. There are no accounts and no update checks.

## Audit and credits

See [AUDIT.md](AUDIT.md) for the security, privacy and quality audit, [CREDITS.md](CREDITS.md) for attribution, and [DESCRIPTION.md](DESCRIPTION.md) for the project blurb. Large-project timings are in [docs/performance.md](docs/performance.md).

## Limitations and known issues

- **Visual Regression** compares captures you supply (baseline vs current folders); the dock's one-click capture runner instantiates each listed scene in an offscreen viewport at the standard resolutions. The capture pass needs a renderer, so it works in the editor or a running game, never in a headless process - CI compares and gates on captures you commit or produce in a real window.
- **Responsive UI Previewer** reads control rectangles from scene text; layouts computed entirely in code at run time are evaluated from their saved rectangles only.
- **Asset Health** measures PNG dimensions from the file header and other formats through Godot's image loader; unused detection follows written `res://` references, so run-time-built path strings are a known blind spot.
- **Dialogue and Quest Debugger** covers the documented JSON format; proprietary dialogue formats need converting to it first. The dock draws one dialogue at a time as a layered branch graph and lists every problem; quest dependencies remain a list (a drawn quest graph is a possible next step).
- **Network Simulator** models the network on a tick clock (deterministic and seeded) rather than shaping real sockets; it tests game logic against bad networks, it is not a firewall tool.
- **Scene Search** parsing is rule-based by design (offline, explainable, no AI service): it stems simple plurals and drops grammar words, and results always state why they matched.
- **Accessibility Checker** checks what can be known statically; colour-only information and reading order still need a human pass - it flags suspects for that pass.
- **Export Doctor** checks configuration and loadability; it does not run a full export (that remains the release step), and the templates check looks in the standard per-user templates folder.
- **Draw-Call Profiler** and **Thermal Dock** produce documented estimates from scene text and workload data, not GPU or device measurements - use them to rank and compare changes, then confirm on real hardware.
- **Shader Doctor** analyzes `.gdshader` text statically; it does not compile shaders or time them on a GPU, and visual-shader graphs are covered through the shading language Godot generates from them.
- **Localization Matrix** does no machine translation and no network calls, per project rule; the in-context half is preview data (completeness, length risk, plural forms) rendered next to the source strings.
- **Leak Hunter** static findings are suspects, not proof; the runtime watcher (detach + weakref sweep) confirms which detached nodes never free in a live session.
- **VFS Mock** models four platform profiles as data and resolves against your real file listing; no platform actually boots, and export-time packing behaviour stays the export step's job.
- **Tilemap Rule Generator** outputs transition specs as data; applying them to a TileSet stays a deliberate human step.
- **Test Runner** detects GUT suites from file text but never depends on GUT; this repo's own suite remains `tests/run_tests.sh`.
- **Whitebox** snapping of live editor selections is dock-side work (Partially Verified in `docs/PARITY.md`); the headless half audits scene text against the grid and slope rules.
- **Prefab Guard** writes to scene files only with an explicit `--apply`; otherwise it reports plans, because scene files are source code.
- Every editor dock is clicked in a real Godot 4.3 editor and every runtime node runs in a live game. These sessions run in CI on Linux under Xvfb with software OpenGL. Hands-on use on Windows with a GPU is still owed; see `QUALITY.md`.

## License

MIT - see `LICENSE`.

## Credits

Built for Godot 4. Uses only the Godot engine's own APIs; no third-party code.
