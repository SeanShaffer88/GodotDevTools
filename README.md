# GodotDevTools

[![Tests](https://github.com/SeanShaffer88/GodotDevTools/actions/workflows/tests.yml/badge.svg)](https://github.com/SeanShaffer88/GodotDevTools/actions/workflows/tests.yml)

Thirty tools for developers who build games with Godot 4: visual regression testing, a game-state time machine, a responsive UI previewer, an asset health dashboard, a dialogue and quest debugger, a multiplayer network simulator, natural-language scene search, an automated accessibility checker, a build and export doctor, a draw-call and batching profiler, a save-game schema migrator, a physics collision matrix visualizer, procedural animation solvers, an audio mixing sandbox, a memory leak and orphan hunter, an input matrix and rebinding suite, a shader analyzer, a signal flow spy, a localization matrix, a behaviour tree and state machine debugger, a camera shake and framing orchestrator, a deterministic seed and replay runner, a level whiteboxing suite, a cross-platform filesystem mock, a tilemap rule generator, a headless test runner, a thermal and battery emulation dock, a prefab instance guard, a GDScript documentation generator, and a scene dependency map.

The [roadmap](ROADMAP.md) tracks 50 proposed tools and their implementation status. The [Demo-to-Release Content Guard](addons/release_guard/README.md) and [Naming and Folder Convention Enforcer](addons/naming_conventions/README.md) are under development, as is the [Subtitle Timing and Readability Auditor](addons/subtitle_audit/README.md).

## TL;DR

Think of this as a workshop wall for a Godot project. Each tool is a separate instrument that hangs on the same wall: you can take down just one and use it in your own game project, or hang all thirty. Each one looks at your game the way a careful tester would - comparing pictures against approved ones, replaying the exact buttons that caused a bug, trying your menus on phone screens, weighing your textures, walking your dialogue, shaking your network, searching your scenes in plain words, checking that every player can read and reach everything, checking your export settings before release day, counting your draw calls, migrating your old saves, mapping your collision layers, solving your animation rigs, mixing your audio on paper, hunting your leaks, laying out your input bindings, reading your shaders, spying on your signals, completing your translations, tracing your behaviour trees, orchestrating your cameras, replaying your seeds, snapping your blockouts, mocking your filesystems, generating your tile rules, running your tests headless, estimating your thermal load, guarding your prefab instances, and documenting your code. Every tool also runs from the command line, so it can guard a build automatically.

AI assistants working in this repo should start at [AI_USAGE.md](AI_USAGE.md): a pasteable project prompt plus the exact file map, inspection order, and full CLI reference with defaults and exit codes.

## The thirty tools

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
| Scene Dependency Map | Browse static scene, script and resource links; flag missing references, cycles, long chains and potentially unused assets. | `addons/scene_dependency` |

Each addon folder has its own README with install steps, editor use, command-line options and limits.

## Screenshots

Real captures are still to be taken on a Windows machine with the plugins enabled in a real project. Capture list:

1. The Asset Health dock after a scan of a real project.
2. The Responsive UI dock listing which screen sizes break a HUD.
3. The Dialogue and Quest dock with a branch problem list.
4. A visual-regression highlight image next to its baseline.

No placeholder images are used in the meantime.

## Requirements

- Godot **4.3** and **4.5** (the prior 29-tool gate passed on both; the new Scene Dependency Map tests still need a Godot run). Other Godot 4.x versions are expected to work - the APIs used (`Image`, `ConfigFile`, `RegEx`, `DirAccess`) are stable across 4.x - but this is **to be confirmed** by a test run.
- No third-party dependencies. No network access is used at any point.

## Install

For one tool: copy its `addons/<tool>` folder into your project's `addons/` folder and enable it under Project -> Project Settings -> Plugins. Ready-made zips are attached to each [GitHub Release](https://github.com/SeanShaffer88/GodotDevTools/releases): `GodotDevTools-<Tool>-v<version>.zip` per tool and `GodotDevTools-Suite-v<version>.zip` with all thirty - unzip into your project root.

For all thirty: copy all thirty `addons/` folders (or unzip the suite zip), then enable the plugins you want. Each tool works on its own; none depends on another.

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

Each CLI's full option list is in its header comment.

## Downloads

Each release carries the installable zips - see [GodotDevTools releases](https://github.com/SeanShaffer88/GodotDevTools/releases): `GodotDevTools-Suite-v<version>.zip` with all thirty addons, or one zip per tool. Pushing a `v*` tag runs the full test gate and then builds and attaches the zips automatically (`.github/workflows/release.yml`), so a release is never published with a red gate.

## Command-line reference

Every CLI writes a JSON and a Markdown report (`--out=<dir>`, `--format=json,md`), prints a summary plus every finding, and exits `0` normally or `2` when a `--fail-on` gate trips (`3` when the scan itself fails, where supported). The full, authoritative option list is in each CLI script's header comment; the main options are:

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
| `scene_dependency/cli/sdm_cli.gd` | `--dir`, repeatable `--root`, `--fail-on=missing_dependency,cycle,long_chain,unused_candidate,unresolved_uid,no_roots` |

## This repo's layout

```
addons/<tool>/            one folder per tool, independently installable
  plugin.cfg, plugin.gd   editor entry point
  core/                   the check itself (no editor APIs)
  ui/                     the editor dock
  cli/                    the headless command-line runner
  runtime/                (time_machine, network_sim, collision_matrix, proc_anim, leak_hunter, input_matrix, signal_spy, bt_debugger, camera_orch, seed_replay) in-game nodes
demo/                     a fixture project with a deliberate problem per tool
tests/                    one suite per tool + run_tests.sh, the full gate
docs/PARITY.md            capability matrix, scored from test evidence
QUALITY.md                quality scorecard
PROJECT_RULES.md          project rule sheet
AI_USAGE.md               AI-agent guide: pasteable prompt + exact tool/CLI map
```

The root of this repo is itself a Godot project: open it, enable the plugins, and run any dock against the `demo/` fixture, which deliberately contains a changed screenshot pair, a rewindable session, an overflowing HUD with tiny low-contrast text and a keyboard-unreachable button, a 3000x2000 texture, a duplicated and an unused asset, inconsistent import settings, a dialogue with a missing branch target and an unreachable room, quests with a missing requirement and a dependency circle, a patrol enemy and a door interaction to search for, an export preset pointing at an icon that does not exist, and one deliberate problem per new tool: an interleaved market scene, a save no registered path can migrate, an all-vs-all collision body, a rig chain that cannot reach its target, a mix layout with a ducking loop, scripts that orphan nodes and circle references, Space bound to two actions, a shader that double-fetches, a signal session with a runaway emitter, a missing translation with a wrong plural rule, a behaviour transition to a state nobody defines, a camera config naming an ease that does not exist, a seed log with one tampered PRNG value, a blockout crate off the grid and a ramp too steep to climb, two files one letter-case apart, a tilemap rule that runs one way only, a test file that never quits, a workload that throttles a low-end estimate, a prefab instance carrying a dead override, and a script with undocumented public API.

## Dialogue and quest data format

The Dialogue and Quest Debugger reads JSON files with `dialogues` and/or `quests` objects: dialogue nodes carry `speaker`, `text`, `choices` (each with `text`, `next`, an optional `condition` of `{var, op, value}` and optional `effects`), a plain `next` for linear flow, or `"end": true`. Quests carry `title` and `requires` (quest ids). See `demo/dialogue/story.json` for a complete example.

## Tests

```sh
sh tests/run_tests.sh /path/to/godot
```

The gate imports the project, runs the per-tool suites (checks counted in QUALITY.md), and exercises the CLIs including the exit-code-2 CI gates on the fixture. The same gate runs automatically on every push and pull request (`.github/workflows/tests.yml`) on Godot 4.3-stable - the verified version - and on 4.5-stable as experimental evidence. Current status: see `QUALITY.md`.

## Troubleshooting

- **A dock is empty or missing.** Project -> Project Settings -> Plugins: make sure that tool's plugin is enabled, then press its **Run check** button.
- **Scene Search finds nothing.** It matches the words in file names, node names, functions, variables and content - not synonyms. Search with the words your project actually uses.
- **Asset Health flags a file you load at run time as unused.** Its path is probably built from pieces at run time. Treat the flag as a prompt to check, not proof.
- **Accessibility contrast looks wrong for a light theme.** Contrast is measured against a dark background by default; set `assumed_background` in the checker core to your game's real background colour.

## Privacy and network behaviour

Everything runs locally, in the editor or a headless Godot process. The tools read your project files and write only the reports you ask for, into your project. Nothing is uploaded, tracked, or sent anywhere. There are no accounts and no update checks.

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
- Editor dock interaction is verified by code inspection and a headless editor import; a hands-on editor session on Windows is still owed - see `QUALITY.md`.

## License

MIT - see `LICENSE`.

## Credits

Built for Godot 4. Uses only the Godot engine's own APIs; no third-party code.
