# GodotDevTools - Capability Parity

Scored from the test gate on Godot 4.3.stable and 4.5.stable (both CI-green). "Verified" = a test check or CLI gate run proves it on the fixture. "Partially Verified" = core logic verified headless; the editor-side experience still owes a hands-on session.

| Capability | Where | Status |
|---|---|---|
| Pixel diff with tolerance, diff count/fraction, changed-region box | visual_regression core | Verified |
| Highlight image (changed pixels in magenta) | visual_regression core + CLI file output | Verified |
| Baseline suite: pass/fail/missing capture/missing baseline, approval copy | visual_regression core | Verified (suite) / approval copy covered by code + suite round-trip in tests |
| Capture plan across resolutions | visual_regression core | Verified |
| Editor-side one-click capture from the dock (scene x resolution -> PNGs) | visual_regression core (vrt_capture.gd) + dock | Built; pure plan/path/report parts Verified, live viewport pass Partially Verified (needs the editor's renderer) |
| Input + snapshot recording, ring buffer | time_machine core | Verified |
| Rewind (snapshot restore), replay script, state diff, state hash | time_machine core | Verified |
| Session save/load/verify as JSON | time_machine core + CLI | Verified |
| In-game recorder node | time_machine runtime | Partially Verified (wraps the verified core; needs a live game session) |
| Stretch/aspect content-rect maths for 9 screen presets incl. notch safe areas | responsive_ui core | Verified |
| Per-control safe-area + minimum-target evaluation from scene text | responsive_ui core | Verified |
| Drawn multi-viewport preview panes in the editor | responsive_ui dock lists results per screen size | Partially Verified |
| Oversized texture + VRAM estimate | asset_health core | Verified |
| Byte-identical duplicate detection | asset_health core | Verified |
| Unused resource detection via reference sweep | asset_health core | Verified |
| Import-setting inconsistency detection | asset_health core | Verified |
| Dialogue graph: missing target, unreachable, dead end, bad start | dialogue_quest core | Verified |
| Quest graph: missing requirement, dependency cycle | dialogue_quest core | Verified |
| Choice simulation with conditions + effects | dialogue_quest core + CLI | Verified |
| Drawn node-graph view of dialogue (layered layout, ghost missing targets, issue colouring) | dialogue_quest core (dqd_layout.gd) + dock GraphView | Built; layout maths Verified (7 test checks), painted pane Partially Verified (needs an editor session) |
| Seeded latency/jitter/loss/duplication/disconnect channel | network_sim core | Verified |
| Sync scenario + desync inspection (hash compare) | network_sim core + CLI | Verified |
| In-game proxy node | network_sim runtime | Partially Verified (wraps the verified core) |
| Project index (nodes, functions, variables, class names) | scene_search core | Verified |
| Rule-based natural-language query parsing + ranked, explained results | scene_search core + CLI | Verified |
| WCAG contrast ratio, tiny text, keyboard focus, colour-only checks | accessibility core | Verified |
| Export diagnosis: project essentials, autoloads, script load, presets, templates, features | export_doctor core + CLI | Verified |
| Draw-call-break suspects (material switches, z-interleave, per-light passes) from scene text | batch_profiler core | Suspect detection Verified; absolute draw-call counts are documented estimates (live RenderingServer monitors need a running game) |
| Save versioning + forward migration (rename/move/default/delete), unmigratable + missing-field flags, registry re-read from disk every run | schema_migrator core + CLI | Verified |
| Layer/mask collision matrix from project settings + scenes, all-vs-all and redundant-raycast flags | collision_matrix core | Verified |
| In-game physics contact counter | collision_matrix runtime | Partially Verified (wraps the verified core; needs a live physics session) |
| Two-bone IK, FABRIK, look-at, squash-and-stretch, foot-placement solvers (2D) from a rig config | proc_anim core | Verified (solver maths checked incl. unreachable-chain failure) |
| Live procedural rig node driving the same solvers | proc_anim runtime | Partially Verified |
| Ducking-chain, reverb-zone and voice-budget simulation on a 10 ms data clock; duck-loop, missing-bus, zone-stuck flags | audio_sandbox core + CLI | Verified (pure simulation; no audio hardware involved) |
| Static leak scan: remove_child-without-free, RefCounted reference circles, signal holds | leak_hunter core | Verified |
| Runtime orphan watcher (detach + weakref sweep) | leak_hunter runtime | Partially Verified (needs a live session) |
| Action-by-device matrix from the live InputMap or JSON, binding collisions, gamepad coverage, remap-menu data | input_matrix core + CLI | Verified |
| In-game rebinding with user:// saves | input_matrix runtime | Partially Verified |
| Static `.gdshader` analysis: redundant/loop texture fetches, branch density, unused uniforms, concrete rewrites | shader_doctor core + CLI | Verified (static text analysis; no GPU timing, no graph-to-code compilation - visual shaders are covered via the code Godot generates) |
| Signal session analysis: emitter-to-listener latency, dropped emissions, cascade depth, recursion, runaway emitters | signal_spy core + CLI | Verified |
| In-game self-spying event bus recorder | signal_spy runtime | Partially Verified |
| Key-by-locale completeness from CSV/PO, overflow-risk lengths, plural-rule checks, orphan tr() keys, in-context preview data | l10n_matrix core + CLI | Verified (no machine translation and no network by design) |
| JSON behaviour validation + run with decision trace (selector/sequence trees, guarded transitions, blackboards) | bt_debugger core + CLI | Verified |
| Runtime behaviour agent sharing the interpreter | bt_debugger runtime | Partially Verified |
| Seeded deterministic shake, ease-curve transitions, deadzone framing maths, config validation | camera_orch core + CLI | Verified |
| Runtime camera rig applying the same functions to a live Camera2D | camera_orch runtime | Partially Verified |
| Log verification by replaying a hand-rolled LCG + FNV-1a chains; first-divergence pinpoint | seed_replay core + CLI | Verified (cross-language anchors asserted in tests) |
| Runtime recorded RNG (seed + draw log) | seed_replay runtime | Partially Verified |
| Grid/rotation snapping + slope maths; headless audit of scene text for off-grid props and too-steep ramps | whitebox core + CLI | Verified |
| Dock-side snapping of live editor selections | whitebox dock | Partially Verified |
| File-op resolution against linux/windows/android/ios rules (case, sandbox, read-only roots, reserved names, length) + script audit for platform-isms | vfs_mock core + CLI | Verified (profile data; no platform actually boots) |
| Terrain peering rule-set validation (asymmetric edges, missing transitions, corner conflicts) + transition spec generation | tilemap_rules core + CLI | Verified (specs are data; applying them to a TileSet stays a human step) |
| Test discovery + classification (harness/GUT detected, GUT never depended on), headless command plan, JUnit XML, --check-only triage | test_runner core + CLI | Verified |
| RC thermal model: time-to-throttle, frame-budget misses, battery hours; device-profile picker dock | thermal_sim core + dock | Model maths Verified; absolute numbers are documented estimates from guessed device constants (comparative use verified; no device measurements exist here) |
| Prefab instance override classification (dead vs hiding), rollback plans, scene writes only under explicit --apply | prefab_guard core + CLI | Verified (apply path fixture-checked; scenes are source code, so writes are opt-in) |
| ## doc comment, signal, export and function parsing to Markdown + dependency-free HTML; undocumented-public-API flagging | doc_gen core + CLI | Verified |
| Scene Dependency Map: literal-reference graph, roots, missing references, cycles, long chains and unused candidates | scene_dependency core + dock + CLI | Unverified (new tests added; static analysis misses dynamic and binary dependencies; hands-on editor session owed) |
| Naming and Folder Convention Enforcer: configurable file and directory naming audit | naming_conventions core + CLI + dock | Verified on fixture in PR #5; editor session pending |
| Naming Conventions: static scene node, signal and group naming audit | naming_conventions core + CLI + dock | Unverified (Godot tests added; text heuristics, editor session pending) |
| Subtitle timing and readability: JSON cue audit | subtitle_audit core + CLI + dock | Unverified (Godot execution and editor session pending; no rendered layout or audio sync checks) |
| Player Telemetry Schema Validator: local event and field validation | telemetry_schema core + CLI + dock | Unverified (Godot tests and editor session pending; no runtime traffic or automatic privacy detection) |
| Performance Regression Gate: scalar baseline comparison and noise tolerances | performance_gate core + CLI + dock | Unverified (Godot tests and editor session pending; benchmarks must be captured separately) |
| Feature Flag and Rollout Simulator: offline cohort, prerequisites and defaults | flag_simulator core + CLI + dock | Unverified (Godot tests and editor session pending; no production service integration) |
| Build Size Attribution Explorer: staged-directory size inventory and budgets | build_size core + CLI + dock | Unverified (Godot tests and editor session pending; archive internals are not attributed) |
| Checklist runner: user-defined requirements and recorded results | cert_check core + CLI + dock | Unverified (Godot tests and editor session pending; no certification claim) |
| State transition coverage: model and trace comparison | state_coverage core + CLI + dock | Verified on fixture in PR #11; optional continuity and truncated-trace handling pending CI |
| State transition coverage: explicit bounded runtime recording | state_coverage core + runtime node | Unverified (headless tests added; real-game and editor session pending; transitions must be recorded explicitly) |
| Test prioritizer: exact path-to-test mappings | test_priority core + CLI + dock | Verified on fixture in PR #11; hands-on editor session pending |
| Test prioritizer: optional dependency-graph impact propagation and evidence | test_priority core + CLI + dock | Unverified (Godot tests added; static graph may miss dynamic dependencies; editor session pending) |
| Subtitle audit: SRT and WebVTT subset import | subtitle_audit core + CLI + dock | Unverified (Godot tests added; rendered layout and editor verification pending) |
| Scene Dependency Map: change impact and rename preview | scene_dependency core + CLI + dock | Unverified (Godot tests added; static reference candidates only, no automatic changes) |
| Asset Health: importer preset comparisons | asset_health core + CLI + dock | Unverified (Godot tests added; imported metadata and editor session required) |
| Asset Health: aggregate uncompressed source texture estimate and budget | asset_health core + CLI + dock | Unverified (Godot tests added; not measured or platform-specific GPU memory) |
| Screenshot review queue: fingerprints and recorded decisions | visual_regression core + CLI + dock | Unverified (Godot tests added; local editable metadata only; no automatic baseline promotion) |
| Particle Budget Inspector: static emitter capacity per scene with instance chains | particle_budget core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Object Pool Advisor: spawn-site scoring plus optional runtime spawn counts | pool_advisor core + CLI + dock + runtime node | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Node Path Breakage Detector: static $/get_node/% resolution against owning scenes | node_paths core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Unused Signal and Method Finder: word-reference counting across scripts and scene connections | unused_symbols core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Typed GDScript Coverage Meter: per-file and project typed share with threshold gate | type_coverage core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Script Complexity Reporter: per-function complexity, length and nesting | script_complexity core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Duplicate Code Detector: normalized line-window clone groups | duplicate_code core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Export Variable Range Auditor: scene and default values against @export_range limits | export_ranges core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Autoload Dependency Graph: reference graph, cycles and init-order hazards | autoload_graph core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Resource UID Integrity Checker: declared vs referenced uid:// values | uid_integrity core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Project Settings Drift Report: key-level diff against a baseline | settings_drift core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Scene Lint Rule Engine: JSON rules over scene node trees | scene_lint core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Loot Table and Economy Simulator: analytic odds plus seeded simulation | loot_sim core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Difficulty Curve Analyzer: per-level power ratio spikes and dips | difficulty_curve core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Damage Formula Sandbox: grid evaluation with range and monotonicity checks | damage_sandbox core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| XP Curve Planner: time-to-level with wall and order checks | xp_curve core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Crafting and Inventory Graph Validator: recipe reachability fixpoint | crafting_graph core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Achievement Reachability Checker: unlock conditions vs declared events and stat caps | achievements core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Wave Spawner Budget Planner: timeline peaks against alive and spawn-rate budgets | wave_budget core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Random Table Fairness Tester: chi-square goodness of fit with p-values | rng_fairness core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Save File Bloat Auditor: per-key size and growth across sample saves | save_bloat core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Dialogue Variable Lint: condition reads vs effect writes in dialogue JSON | dialogue_vars core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Font Glyph Coverage Checker: translation characters against TTF/OTF cmap | font_glyphs core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Audio Loudness and Clipping Auditor: PCM WAV peak, RMS, clipping, DC offset, rate | audio_levels core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Audio Import Settings Auditor: loop/compression settings vs role and length | audio_import core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Texture Atlas Packing Planner: shelf packing estimate from sizes | atlas_planner core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Texture Filter Consistency Checker: pixel-art import settings and default filter | texture_filter core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Mesh Statistics Report: glTF/GLB accessor-based counts vs budgets | mesh_stats core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| 3D Light and Shadow Cost Estimator: light and shadow counts per scene | light_cost core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Environment Feature Cost Matrix: enabled features, cost tiers, Compatibility support | env_cost core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Colour Palette Consistency Checker: CIE76 delta E against a palette | palette_check core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Theme Resource Auditor: override sprawl, font-size scale, unused variations | theme_audit core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Flaky Test Detector: JUnit/JSON run history analysis | flaky_tests core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Golden Data Snapshot Tester: path-level JSON diffs against goldens | golden_snapshot core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Error Log Grouper: normalized signature grouping of Godot logs | log_grouper core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Log Warning Budget Gate: counts and new signatures vs baseline | log_budget core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| State Trace Determinism Diff: first divergence between two traces | trace_diff core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Input Sequence Fuzzer: seeded sequences from InputMap plus replay node | input_fuzzer core + CLI + dock + runtime node | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| GDScript Warning Baseline: static warning-pattern counts vs baseline | warning_baseline core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Scene Load Smoke Tester: headless load + instantiate of every scene | scene_smoke core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Micro-Benchmark Harness: repeated timing with gate-compatible output | bench_harness core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| GDScript Mutation Tester: operator mutants run in an isolated project copy | mutation_tester core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Store Asset Validator: image sizes and counts against a user profile | store_assets core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Android Permissions Reviewer: export preset permissions for human review | android_permissions core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Version Consistency Checker: project version vs export preset versions | version_consistency core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Third-Party Notice Collector: license file gathering and keyword identification | third_party_notices core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Release Notes Generator: conventional-commit grouping into a draft | release_notes core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Content Descriptor Checklist: questionnaire completeness and freshness | content_descriptor core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Patch Delta Estimator: file-level diff of two staged builds | patch_delta core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Settings File Validator: schema validation of settings files | settings_validator core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Accessibility Options Coverage: keyword evidence of expected player options | a11y_options core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Handheld Readiness Checklist: stretch, scaled text size, gamepad bindings, focus | handheld_readiness core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Report Schema: JSON Schema document plus validator | report_schema core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| SARIF Exporter: reports to SARIF 2.1.0 | sarif_export core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| JUnit Exporter: reports to JUnit XML | junit_export core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Static HTML Dashboard: offline single-page report summary | html_dashboard core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Report Diff: new/fixed/unchanged findings between two runs | report_diff core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Finding Suppression Baseline: justified, expiring suppressions over reports | suppressions core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Suite CLI Dispatcher: tool discovery and pass-through runner | suite_dispatcher core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Pre-commit Hook Installer: generated POSIX hook, guarded install/uninstall | precommit core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Shader Variant Budget Manager: material feature combos and preprocessor branches | shader_variants core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| LOD and Visibility Range Planner: ranges, heavy instances, import LOD flags | lod_planner core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Animation Performance Auditor: constant tracks, redundant and duplicate keys | anim_audit core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Rendering Settings Compatibility Matrix: used features vs renderer support | render_compat core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| GPU Budget and Overdraw Analyzer: static 2D overdraw and fill-rate estimate | overdraw core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Frame-Time Spike Investigator: offline spike correlation plus runtime recorder | frame_spikes core + CLI + dock + runtime node | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Startup and Scene-Load Profiler: measured load/instantiate timing | load_profiler core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Physics Jitter and Tunneling Detector: static tunneling and jitter risks | physics_jitter core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Character Controller Test Course: kinematic reachability of course obstacles | controller_course core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Hitbox and Hurtbox Timeline Viewer: active windows from animation tracks | hitbox_timeline core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Navigation Mesh Diagnostic Lab: 2D navmesh connectivity and clearance | navmesh_lab core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Spawn Point and Encounter Validator: blocked, crowded and off-mesh spawns | spawn_validator core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Interaction Reachability Checker: trigger areas vs reachable navmesh | interaction_reach core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| World Boundary and Out-of-Bounds Auditor: level extents vs kill zones and boundaries | world_bounds core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| AI Perception Debugger: traced sight/hearing decisions against expectations | ai_perception core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Gameplay Ability Simulator: fixed-step rotation simulation | ability_sim core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Procedural Generation Constraint Tester: flood-fill constraints over generated maps | procgen_constraints core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Controller Glyph and Prompt Validator: prompt tokens vs actions, bindings and glyphs | controller_glyphs core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Color-Vision and Contrast Previewer: CVD simulation of palette pairs | colorvision core + CLI + dock | Partially Verified (headless suite and CLI gate pass on Godot 4.3; editor session pending) |
| Every tool: editor dock with tooltips + offline help | ui/ docks | Partially Verified (headless import passes; hands-on editor session owed) |
| Every tool: headless CLI with JSON/Markdown reports and --fail-on gates | cli/ | Verified |
| Full gate runs automatically on push/PR, on Godot 4.3-stable and 4.5-stable | .github/workflows/tests.yml | Verified (CI green on both) |
| Releases: zips built from addons/ and attached on v* tags, gate runs first | .github/workflows/release.yml | Built; not yet exercised by a real tag push |
