# GodotDevTools - Capability Parity

Scored from evidence that runs in CI. The test gate runs on Godot 4.3-stable and 4.5-stable. On Godot 4.3, two more sessions run under Xvfb with software OpenGL: a real-editor session that clicks every enabled dock's run button (`tests/editor/run_editor_session.sh`) and a live-game session for the existing runtime nodes (`tests/game/run_live_game.sh`). Historical broad claims below describe the baseline before the three new Android addons; their current evidence is recorded separately at the end.

- **Verified**: a test check, CLI gate or one of those sessions proves it.
- **Partially Verified**: the core is verified and the dock passes the editor session, but this particular editor interaction is not automated.
- **Hands-on Windows use with a hardware GPU** is still owed. The Windows CI runner does not guarantee a hardware GPU.

| Capability | Where | Status |
|---|---|---|
| Pixel diff with tolerance, diff count/fraction, changed-region box | visual_regression core | Verified |
| Highlight image (changed pixels in magenta) | visual_regression core + CLI file output | Verified |
| Baseline suite: pass/fail/missing capture/missing baseline, approval copy | visual_regression core | Verified (suite) / approval copy covered by code + suite round-trip in tests |
| Capture plan across resolutions | visual_regression core | Verified |
| Editor-side one-click capture from the dock (scene x resolution -> PNGs) | visual_regression core (vrt_capture.gd) + dock | Verified on a colored fixture in windowed Linux/Windows CI: the button writes images at all five sizes with expected content |
| Input + snapshot recording, ring buffer | time_machine core | Verified |
| Rewind (snapshot restore), replay script, state diff, state hash | time_machine core | Verified |
| Session save/load/verify as JSON | time_machine core + CLI | Verified |
| In-game recorder node | time_machine runtime | Verified (live game: records physics frames, rewinds state) |
| Stretch/aspect content-rect maths for 9 screen presets incl. notch safe areas | responsive_ui core | Verified |
| Per-control safe-area + minimum-target evaluation from scene text | responsive_ui core | Verified |
| Drawn multi-viewport preview panes in the editor | responsive_ui dock | Verified on a colored fixture in windowed Linux/Windows CI; does not simulate device safe areas or project window stretch |
| Oversized texture + VRAM estimate | asset_health core | Verified |
| Byte-identical duplicate detection | asset_health core | Verified |
| Unused resource detection via reference sweep | asset_health core | Verified |
| Import-setting inconsistency detection | asset_health core | Verified |
| Dialogue graph: missing target, unreachable, dead end, bad start | dialogue_quest core | Verified |
| Quest graph: missing requirement, dependency cycle | dialogue_quest core | Verified |
| Choice simulation with conditions + effects | dialogue_quest core + CLI | Verified |
| Drawn node-graph view of dialogue (layered layout, ghost missing targets, issue colouring) | dialogue_quest core (dqd_layout.gd) + dock GraphView | Verified on one fixture in windowed Linux/Windows CI, including a sampled painted warning outline |
| Seeded latency/jitter/loss/duplication/disconnect channel | network_sim core | Verified |
| Sync scenario + desync inspection (hash compare) | network_sim core + CLI | Verified |
| In-game proxy node | network_sim runtime | Verified (live game: delivery after the configured latency) |
| Project index (nodes, functions, variables, class names) | scene_search core | Verified |
| Rule-based natural-language query parsing + ranked, explained results | scene_search core + CLI | Verified |
| WCAG contrast ratio, tiny text, keyboard focus, colour-only checks | accessibility core | Verified |
| Export diagnosis: project essentials, autoloads, script load, presets, templates, features | export_doctor core + CLI | Verified |
| Draw-call-break suspects (material switches, z-interleave, per-light passes) from scene text | batch_profiler core | Suspect detection Verified; absolute draw-call counts are documented estimates (live RenderingServer monitors need a running game) |
| Save versioning + forward migration (rename/move/default/delete), unmigratable + missing-field flags, registry re-read from disk every run | schema_migrator core + CLI | Verified |
| Layer/mask collision matrix from project settings + scenes, all-vs-all and redundant-raycast flags | collision_matrix core | Verified |
| In-game physics contact counter | collision_matrix runtime | Verified (live game: counts a real physics contact by layer bit) |
| Two-bone IK, FABRIK, look-at, squash-and-stretch, foot-placement solvers (2D) from a rig config | proc_anim core | Verified (solver maths checked incl. unreachable-chain failure) |
| Live procedural rig node driving the same solvers | proc_anim runtime | Verified (live game: two-bone IK reaches its target) |
| Ducking-chain, reverb-zone and voice-budget simulation on a 10 ms data clock; duck-loop, missing-bus, zone-stuck flags | audio_sandbox core + CLI | Verified (pure simulation; no audio hardware involved) |
| Static leak scan: remove_child-without-free, RefCounted reference circles, signal holds | leak_hunter core | Verified |
| Runtime orphan watcher (detach + weakref sweep) | leak_hunter runtime | Verified (live game: flags the detached node, not the freed one) |
| Action-by-device matrix from the live InputMap or JSON, binding collisions, gamepad coverage, remap-menu data | input_matrix core + CLI | Verified |
| In-game rebinding with user:// saves | input_matrix runtime | Verified (live game: rebinds from a real key event) |
| Static `.gdshader` analysis: redundant/loop texture fetches, branch density, unused uniforms, concrete rewrites | shader_doctor core + CLI | Verified (static text analysis; no GPU timing, no graph-to-code compilation - visual shaders are covered via the code Godot generates) |
| Signal session analysis: emitter-to-listener latency, dropped emissions, cascade depth, recursion, runaway emitters | signal_spy core + CLI | Verified |
| In-game self-spying event bus recorder | signal_spy runtime | Verified (live game: emits, handlers and cascade parents) |
| Key-by-locale completeness from CSV/PO, overflow-risk lengths, plural-rule checks, orphan tr() keys, in-context preview data | l10n_matrix core + CLI | Verified (no machine translation and no network by design) |
| JSON behaviour validation + run with decision trace (selector/sequence trees, guarded transitions, blackboards) | bt_debugger core + CLI | Verified |
| Runtime behaviour agent sharing the interpreter | bt_debugger runtime | Verified (live game: ticks on frames, changes state from the blackboard) |
| Seeded deterministic shake, ease-curve transitions, deadzone framing maths, config validation | camera_orch core + CLI | Verified |
| Runtime camera rig applying the same functions to a live Camera2D | camera_orch runtime | Verified (live game: follows its target; shake moves the Camera2D offset) |
| Log verification by replaying a hand-rolled LCG + FNV-1a chains; first-divergence pinpoint | seed_replay core + CLI | Verified (cross-language anchors asserted in tests) |
| Runtime recorded RNG (seed + draw log) | seed_replay runtime | Verified (live game: same seed, same rolls; the live session found and fixed randi_range/randf_range resolving to the unseeded global randf) |
| Grid/rotation snapping + slope maths; headless audit of scene text for off-grid props and too-steep ramps | whitebox core + CLI | Verified |
| Dock-side snapping of live editor selections | whitebox dock | Verified on a 3D-node fixture in windowed Linux/Windows CI, including Undo and Redo; snaps local positions only |
| File-op resolution against linux/windows/android/ios rules (case, sandbox, read-only roots, reserved names, length) + script audit for platform-isms | vfs_mock core + CLI | Verified (profile data; no platform actually boots) |
| Terrain peering rule-set validation (asymmetric edges, missing transitions, corner conflicts) + transition spec generation | tilemap_rules core + CLI | Verified (specs are data; applying them to a TileSet stays a human step) |
| Test discovery + classification (harness/GUT detected, GUT never depended on), headless command plan, JUnit XML, --check-only triage | test_runner core + CLI | Verified |
| RC thermal model: time-to-throttle, frame-budget misses, battery hours; device-profile picker dock | thermal_sim core + dock | Model maths Verified; absolute numbers are documented estimates from guessed device constants (comparative use verified; no device measurements exist here) |
| Prefab instance override classification (dead vs hiding), rollback plans, scene writes only under explicit --apply | prefab_guard core + CLI | Verified (apply path fixture-checked; scenes are source code, so writes are opt-in) |
| ## doc comment, signal, export and function parsing to Markdown + dependency-free HTML; undocumented-public-API flagging | doc_gen core + CLI | Verified |
| Scene Dependency Map: literal-reference graph, roots, missing references, cycles, long chains and unused candidates | scene_dependency core + dock + CLI | Verified (gate on 4.3/4.5; dock in the editor session; static analysis can miss dynamic and binary dependencies) |
| Naming and Folder Convention Enforcer: configurable file and directory naming audit | naming_conventions core + CLI + dock | Gate including sidecar regressions passed on Linux 4.3/4.5 and Windows 4.3; two small real-project scans passed. Dock exercised in the editor session; production-scale and hands-on use remain unverified. |
| Naming Conventions: static scene node, signal and group naming audit | naming_conventions core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; text heuristics) |
| Subtitle timing and readability: JSON cue audit | subtitle_audit core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; no audio sync) |
| Player Telemetry Schema Validator: local event and field validation | telemetry_schema core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; no runtime traffic or automatic privacy detection) |
| Performance Regression Gate: scalar baseline comparison and noise tolerances | performance_gate core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; benchmarks are captured separately) |
| Feature Flag and Rollout Simulator: offline cohort, prerequisites and defaults | flag_simulator core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; no production service integration) |
| Build Size Attribution Explorer: staged-directory size inventory and budgets | build_size core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session) |
| Checklist runner: user-defined requirements and recorded results | cert_check core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; no certification claim) |
| State transition coverage: model and trace comparison | state_coverage core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session) |
| State transition coverage: explicit bounded runtime recording | state_coverage core + runtime node | Verified (live game: records transitions during play; transitions are recorded explicitly) |
| Test prioritizer: exact path-to-test mappings | test_priority core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session) |
| Test prioritizer: optional dependency-graph impact propagation and evidence | test_priority core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; static graph may miss dynamic dependencies) |
| Subtitle audit: SRT and WebVTT subset import | subtitle_audit core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session) |
| Scene Dependency Map: change impact and rename preview | scene_dependency core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; candidates only, no automatic changes) |
| Asset Health: importer preset comparisons | asset_health core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; needs existing import metadata) |
| Asset Health: aggregate uncompressed source texture estimate and budget | asset_health core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; source-side estimate) |
| Screenshot review queue: fingerprints and recorded decisions | visual_regression core + CLI + dock | Verified (gate on 4.3/4.5; dock in the editor session; baseline promotion is manual by design) |
| Particle Budget Inspector: static emitter capacity per scene with instance chains | particle_budget core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Object Pool Advisor: spawn-site scoring plus optional runtime spawn counts | pool_advisor core + CLI + dock + runtime node | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session; runtime node in the live game) |
| Node Path Breakage Detector: static $/get_node/% resolution against owning scenes | node_paths core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Unused Signal and Method Finder: word-reference counting across scripts and scene connections | unused_symbols core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Typed GDScript Coverage Meter: per-file and project typed share with threshold gate | type_coverage core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Script Complexity Reporter: per-function complexity, length and nesting | script_complexity core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Duplicate Code Detector: normalized line-window clone groups | duplicate_code core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Export Variable Range Auditor: scene and default values against @export_range limits | export_ranges core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Autoload Dependency Graph: reference graph, cycles and init-order hazards | autoload_graph core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Resource UID Integrity Checker: declared vs referenced uid:// values | uid_integrity core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Project Settings Drift Report: key-level diff against a baseline | settings_drift core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Scene Lint Rule Engine: JSON rules over scene node trees | scene_lint core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Loot Table and Economy Simulator: analytic odds plus seeded simulation | loot_sim core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Difficulty Curve Analyzer: per-level power ratio spikes and dips | difficulty_curve core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Damage Formula Sandbox: grid evaluation with range and monotonicity checks | damage_sandbox core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| XP Curve Planner: time-to-level with wall and order checks | xp_curve core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Crafting and Inventory Graph Validator: recipe reachability fixpoint | crafting_graph core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Achievement Reachability Checker: unlock conditions vs declared events and stat caps | achievements core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Wave Spawner Budget Planner: timeline peaks against alive and spawn-rate budgets | wave_budget core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Random Table Fairness Tester: chi-square goodness of fit with p-values | rng_fairness core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Save File Bloat Auditor: per-key size and growth across sample saves | save_bloat core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Dialogue Variable Lint: condition reads vs effect writes in dialogue JSON | dialogue_vars core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Font Glyph Coverage Checker: translation characters against TTF/OTF cmap | font_glyphs core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Audio Loudness and Clipping Auditor: PCM WAV peak, RMS, clipping, DC offset, rate | audio_levels core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Audio Import Settings Auditor: loop/compression settings vs role and length | audio_import core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Texture Atlas Packing Planner: shelf packing estimate from sizes | atlas_planner core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Texture Filter Consistency Checker: pixel-art import settings and default filter | texture_filter core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Mesh Statistics Report: glTF/GLB accessor-based counts vs budgets | mesh_stats core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| 3D Light and Shadow Cost Estimator: light and shadow counts per scene | light_cost core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Environment Feature Cost Matrix: enabled features, cost tiers, Compatibility support | env_cost core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Colour Palette Consistency Checker: CIE76 delta E against a palette | palette_check core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Theme Resource Auditor: override sprawl, font-size scale, unused variations | theme_audit core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Flaky Test Detector: JUnit/JSON run history analysis | flaky_tests core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Golden Data Snapshot Tester: path-level JSON diffs against goldens | golden_snapshot core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Error Log Grouper: normalized signature grouping of Godot logs | log_grouper core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Log Warning Budget Gate: counts and new signatures vs baseline | log_budget core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| State Trace Determinism Diff: first divergence between two traces | trace_diff core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Input Sequence Fuzzer: seeded sequences from InputMap plus replay node | input_fuzzer core + CLI + dock + runtime node | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session; runtime node in the live game) |
| GDScript Warning Baseline: static warning-pattern counts vs baseline | warning_baseline core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Scene Load Smoke Tester: headless load + instantiate of every scene | scene_smoke core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Micro-Benchmark Harness: repeated timing with gate-compatible output | bench_harness core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| GDScript Mutation Tester: operator mutants run in an isolated project copy | mutation_tester core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Store Asset Validator: image sizes and counts against a user profile | store_assets core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Android Permissions Reviewer: export preset permissions for human review | android_permissions core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Version Consistency Checker: project version vs export preset versions | version_consistency core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Third-Party Notice Collector: license file gathering and keyword identification | third_party_notices core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Release Notes Generator: conventional-commit grouping into a draft | release_notes core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Content Descriptor Checklist: questionnaire completeness and freshness | content_descriptor core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Patch Delta Estimator: file-level diff of two staged builds | patch_delta core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Settings File Validator: schema validation of settings files | settings_validator core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Accessibility Options Coverage: keyword evidence of expected player options | a11y_options core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Handheld Readiness Checklist: stretch, scaled text size, gamepad bindings, focus | handheld_readiness core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Report Schema: JSON Schema document plus validator | report_schema core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| SARIF Exporter: reports to SARIF 2.1.0 | sarif_export core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| JUnit Exporter: reports to JUnit XML | junit_export core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Static HTML Dashboard: offline single-page report summary | html_dashboard core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Report Diff: new/fixed/unchanged findings between two runs | report_diff core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Finding Suppression Baseline: justified, expiring suppressions over reports | suppressions core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Suite CLI Dispatcher: tool discovery and pass-through runner | suite_dispatcher core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Pre-commit Hook Installer: generated POSIX hook, guarded install/uninstall | precommit core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Shader Variant Budget Manager: material feature combos and preprocessor branches | shader_variants core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| LOD and Visibility Range Planner: ranges, heavy instances, import LOD flags | lod_planner core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Animation Performance Auditor: constant tracks, redundant and duplicate keys | anim_audit core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Rendering Settings Compatibility Matrix: used features vs renderer support | render_compat core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| GPU Budget and Overdraw Analyzer: static 2D overdraw and fill-rate estimate | overdraw core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Frame-Time Spike Investigator: offline spike correlation plus runtime recorder | frame_spikes core + CLI + dock + runtime node | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session; runtime node in the live game) |
| Startup and Scene-Load Profiler: measured load/instantiate timing | load_profiler core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Physics Jitter and Tunneling Detector: static tunneling and jitter risks | physics_jitter core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Character Controller Test Course: kinematic reachability of course obstacles | controller_course core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Hitbox and Hurtbox Timeline Viewer: active windows from animation tracks | hitbox_timeline core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Navigation Mesh Diagnostic Lab: 2D navmesh connectivity and clearance | navmesh_lab core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Spawn Point and Encounter Validator: blocked, crowded and off-mesh spawns | spawn_validator core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Interaction Reachability Checker: trigger areas vs reachable navmesh | interaction_reach core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| World Boundary and Out-of-Bounds Auditor: level extents vs kill zones and boundaries | world_bounds core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| AI Perception Debugger: traced sight/hearing decisions against expectations | ai_perception core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Gameplay Ability Simulator: fixed-step rotation simulation | ability_sim core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Procedural Generation Constraint Tester: flood-fill constraints over generated maps | procgen_constraints core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Controller Glyph and Prompt Validator: prompt tokens vs actions, bindings and glyphs | controller_glyphs core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Color-Vision and Contrast Previewer: CVD simulation of palette pairs | colorvision core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Scene Merge Conflict Assistant: conflict hunks explained by node and property | merge_conflicts core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Project Cleanup Workbench: candidate list for manual cleanup | cleanup_workbench core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Scene Review Snapshot Generator: scene inventory and diff | scene_snapshot core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Node Property Drift Monitor: convention outliers and baseline deviations | property_drift core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Art-to-Engine Handoff Validator: glTF export hygiene | art_handoff core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Gameplay Scenario Test Builder: JSON steps run by a physics-frame runner | scenario_tests core + CLI + dock + runtime node | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session; runtime node in the live game) |
| Crash and Error Reproduction Packager: redacted local bundle | crash_packager core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Save Corruption and Recovery Tester: mutated saves against a loader | save_corruption core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Property-Based Gameplay Tester: generation, checking and shrinking | property_tests core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Resource Load Failure Simulator: static failure-path analysis of loads | load_failure core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Pause, Focus, and Lifecycle Tester: pause behaviour and lifecycle handling | lifecycle core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Privacy and Permissions Auditor: data-touching API inventory | privacy_audit core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Offline and Poor-Connection Test Harness: static checks plus seeded fault-injecting HTTP node | offline_harness core + CLI + dock + runtime node | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session; runtime node in the live game) |
| Editor Action Macro Recorder: recorded property macros with preview and explicit apply | macro_recorder core + CLI + dock | Verified (headless suite and CLI gate on Godot 4.3 and 4.5; dock in the editor session) |
| Earlier 133-tool baseline: editor docks with tooltips | ui/ docks | Verified (baseline docks: tooltips by `tests/test_docks.gd`; real clicks in a real editor session by `tests/editor`, including Macro Recorder preview and Inspector-edit recording) |
| Earlier baseline: headless CLIs with JSON/Markdown reports and --fail-on gates | cli/ | Verified |
| Full gate runs automatically on push/PR, on Godot 4.3-stable and 4.5-stable | .github/workflows/tests.yml | Verified (CI green on both) |
| Releases: zips built from addons/ and attached on v* tags, gate runs first | .github/workflows/release.yml | Verified (v1.2.0: gate passed, 134 zips published) |
| Asset Health: per-platform GPU texture estimates (desktop BC1/BC3/BC7/BC5, mobile ETC2/ASTC) and platform budgets | asset_health core + CLI | Verified (format and size rules tested; estimates from import settings, not device measurements) |
| Subtitle audit: rendered layout in a safe-area box | subtitle_audit core + CLI | Verified (engine TextParagraph wrapping; line counts match a rendered Label in the live game) |
| Build Size: attribution inside Godot packs (format 2/3, standalone or embedded) | build_size core + CLI | Verified (packs written by Godot 4.3 and 4.5 read with exact sizes) |
| Real-editor session and live-game session in CI | tests/editor, tests/game, tests.yml `sessions` job | Verified (Linux, Xvfb, Mesa llvmpipe) |

| Problem-first tool search, ranked with reasons | tool_finder core | Headless gate and general editor session passed in CI |
| Fix preview and opt-in apply | fix_engine core | Gate and apply/backup regression tests passed in CI; references and concurrent filesystem changes remain limitations |
| Plugin presets (full/ci_only/mobile_perf/content/testing) | suite_presets core | Gate and general editor session passed in CI; opt-in apply/backup is regression-tested |
| Coverage estimate from test evidence + trend | coverage_gate core + tools/coverage | Gate and general editor session passed in CI; estimate only, not measured coverage |
| Dock tooltip/focus/run-action audit | dock_a11y core + test_docks focus check | Gate and general editor session passed in CI; source audit is heuristic |
| Windows gate + sessions | windows-gpu.yml | Passed on hosted CI; hardware-GPU and hands-on use still unverified |
| MCP server (stdlib stdio) + VSCode SARIF | mcp/, editors/vscode/ | Initialization and tool-list smoke-tested; Godot-backed calls and VS Code integration unverified |
| Docker image + standalone naming subset | Dockerfile, tools/gdt, tools/standalone | Image help, mounted-project list/Android-export smoke and the full gate in a disposable mount passed in a real container in [post-merge CI](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43104898029/job/130805553528). Standalone/Godot CLI naming parity passed on Linux 4.3/4.5, experimental 4.4/4.6, and Windows 4.3 CI. No Android device behavior was tested. |
| Release packaging and Asset Library metadata | tools/release/, tools/assetlib/ | [CI](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43110058555/job/130823389959) built and compared every addon and suite archive and tagged metadata. One extracted addon from each archive type passed synthetic CLI smokes using [official Godot 4.3](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43110058555/job/130823390355) on code commit `0ab81d2`; this does not cover every addon or Android devices. No new release or Asset Library submission has been published; verify actual assets before submission. |
| Dogfood harness + false-positive log | tests/dogfood/, docs/DOGFOOD.md | Four scanners completed on pinned Brackeys and platformer projects in Godot 4.5 CI; sample review confirmed sidecar false positives. Full adjudication, a measured false-positive rate and production-scale dogfooding remain outstanding. |

## Android additions (2026-11-11)

At code commit `1678b02`, the full [Linux CI gate](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43033846983) passed on Godot 4.3 and 4.5, plus the experimental 4.4 and 4.6 targets. The [Windows CI gate](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43033846801) passed on 4.3. Both workflows also passed their general editor run-button and existing live-game sessions. Hosted sessions do not prove hardware-GPU behavior or Android device behavior.

| Capability | Evidence and limits |
|---|---|
| Android export preset and supplied version-code history audit | The full gates include `tests/test_aea.gd`, CLI clean/exit-2/exit-1 cases and fixture-secret omission checks. 28 checks also passed locally in a minimal source-built 4.3 template. No actual Android export or store submission was tested. |
| Android touch/safe-area snapshot analysis and capture helper | The full gates include `tests/test_ata.gd` and CLI cases; 32 local checks covered synthetic geometry, capture from a headless scene tree, limits and explicit file writing. Coordinate mapping and touch handling have not been verified on an Android device. |
| Android logcat crash triage | The full gates include `tests/test_alt.gd` and CLI cases; 23 local checks used synthetic threadtime logs, including grouping, package filters and omission of fake secrets. No real-device logs or native symbolication were validated. |
| Three Android dock wrappers | `tests/test_android_docks.gd` passed 11 headless checks for tooltips/focus, supplied fixture inputs and output refresh. The Linux and Windows editor sessions clicked each new dock's general run button; they did not validate every control interaction or the Android capture helper on a device. |

The initial [Docker image build](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43033846869) failed before its smoke test, with logs unavailable in this sandbox. A [diagnostic rerun](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43035324442) showed that the Docker build container could not resolve Ubuntu package servers. A subsequent [host-network attempt](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43035527114) failed with the same DNS symptoms, so that speculative change was reverted. The [post-merge main run](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43091602232) subsequently passed the image build and help smoke without a networking workaround. This confirms recovery for that run, not the underlying cause or mounted-project behavior. The workflow emits bounded failure diagnostics if a future build fails.
