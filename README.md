# GodotDevTools

Nine tools for developers who build games with Godot 4: visual regression testing, a game-state time machine, a responsive UI previewer, an asset health dashboard, a dialogue and quest debugger, a multiplayer network simulator, natural-language scene search, an automated accessibility checker, and a build and export doctor.

## TL;DR

Think of this as a workshop wall for a Godot project. Each tool is a separate instrument that hangs on the same wall: you can take down just one and use it in your own game project, or hang all nine. Each one looks at your game the way a careful tester would - comparing pictures against approved ones, replaying the exact buttons that caused a bug, trying your menus on phone screens, weighing your textures, walking your dialogue, shaking your network, searching your scenes in plain words, checking that every player can read and reach everything, and checking your export settings before release day. Every tool also runs from the command line, so it can guard a build automatically.

## The nine tools

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

Each addon folder has its own README with install steps, editor use, command-line options and limits.

## Screenshots

Real captures are still to be taken on a Windows machine with the plugins enabled in a real project. Capture list:

1. The Asset Health dock after a scan of a real project.
2. The Responsive UI dock listing which screen sizes break a HUD.
3. The Dialogue and Quest dock with a branch problem list.
4. A visual-regression highlight image next to its baseline.

No placeholder images are used in the meantime.

## Requirements

- Godot **4.3** (verified). Other Godot 4.x versions are expected to work - the APIs used (`Image`, `ConfigFile`, `RegEx`, `DirAccess`) are stable across 4.x - but this is **to be confirmed** by a test run.
- No third-party dependencies. No network access is used at any point.

## Install

For one tool: copy its `addons/<tool>` folder into your project's `addons/` folder and enable it under Project -> Project Settings -> Plugins. Ready-made zips are in this repo's root: `GodotDevTools-<Tool>-v1.0.0.zip` per tool and `GodotDevTools-Suite-v1.0.0.zip` with all nine - unzip into your project root.

For all nine: copy all nine `addons/` folders (or unzip the suite zip), then enable the plugins you want. Each tool works on its own; none depends on another.

## How to use

### In the editor

Each tool adds a dock on the right side of the editor with a **Run check** button, a results list, and a `?` help button that explains the tool in plain words, offline. Two tools also add runtime pieces you place in your game while testing:

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

The v1.0.0 release carries the installable zips: [GodotDevTools v1.0.0](https://github.com/SeanShaffer88/GodotDevTools/releases/tag/v1.0.0) — `GodotDevTools-Suite-v1.0.0.zip` with all nine addons, or one zip per tool. The same zips are also in this repo's root for convenience.

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

## This repo's layout

```
addons/<tool>/            one folder per tool, independently installable
  plugin.cfg, plugin.gd   editor entry point
  core/                   the check itself (no editor APIs)
  ui/                     the editor dock
  cli/                    the headless command-line runner
  runtime/                (time_machine, network_sim) in-game test nodes
demo/                     a fixture project with a deliberate problem per tool
tests/                    one suite per tool + run_tests.sh, the full gate
docs/PARITY.md            capability matrix, scored from test evidence
QUALITY.md                quality scorecard
PROJECT_RULES.md          project rule sheet
```

The root of this repo is itself a Godot project: open it, enable the plugins, and run any dock against the `demo/` fixture, which deliberately contains a changed screenshot pair, a rewindable session, an overflowing HUD with tiny low-contrast text and a keyboard-unreachable button, a 3000x2000 texture, a duplicated and an unused asset, inconsistent import settings, a dialogue with a missing branch target and an unreachable room, quests with a missing requirement and a dependency circle, a patrol enemy and a door interaction to search for, and an export preset pointing at an icon that does not exist.

## Dialogue and quest data format

The Dialogue and Quest Debugger reads JSON files with `dialogues` and/or `quests` objects: dialogue nodes carry `speaker`, `text`, `choices` (each with `text`, `next`, an optional `condition` of `{var, op, value}` and optional `effects`), a plain `next` for linear flow, or `"end": true`. Quests carry `title` and `requires` (quest ids). See `demo/dialogue/story.json` for a complete example.

## Tests

```sh
sh tests/run_tests.sh /path/to/godot
```

The gate imports the project, runs the per-tool suites (checks counted in QUALITY.md), and exercises the CLIs including the exit-code-2 CI gates on the fixture. Current status: see `QUALITY.md` - the gate is green on Godot 4.3.stable.

## Troubleshooting

- **A dock is empty or missing.** Project -> Project Settings -> Plugins: make sure that tool's plugin is enabled, then press its **Run check** button.
- **Scene Search finds nothing.** It matches the words in file names, node names, functions, variables and content - not synonyms. Search with the words your project actually uses.
- **Asset Health flags a file you load at run time as unused.** Its path is probably built from pieces at run time. Treat the flag as a prompt to check, not proof.
- **Accessibility contrast looks wrong for a light theme.** Contrast is measured against a dark background by default; set `assumed_background` in the checker core to your game's real background colour.

## Privacy and network behaviour

Everything runs locally, in the editor or a headless Godot process. The tools read your project files and write only the reports you ask for, into your project. Nothing is uploaded, tracked, or sent anywhere. There are no accounts and no update checks.

## Limitations and known issues

- **Visual Regression** compares captures you supply (baseline vs current folders) and the editor dock does not yet press the shutter for you: capturing from a running scene across resolutions is done with Godot's viewport screenshot in your own test scene; the compare, highlight, baseline approval and CI gate are the tool's job. (A one-click capture runner is the top roadmap item.)
- **Responsive UI Previewer** reads control rectangles from scene text; layouts computed entirely in code at run time are evaluated from their saved rectangles only.
- **Asset Health** measures PNG dimensions from the file header and other formats through Godot's image loader; unused detection follows written `res://` references, so run-time-built path strings are a known blind spot.
- **Dialogue and Quest Debugger** covers the documented JSON format; proprietary dialogue formats need converting to it first. The graph is presented as branch/dependency lists with full simulation; a drawn node-graph view is a roadmap item.
- **Network Simulator** models the network on a tick clock (deterministic and seeded) rather than shaping real sockets; it tests game logic against bad networks, it is not a firewall tool.
- **Scene Search** parsing is rule-based by design (offline, explainable, no AI service): it stems simple plurals and drops grammar words, and results always state why they matched.
- **Accessibility Checker** checks what can be known statically; colour-only information and reading order still need a human pass - it flags suspects for that pass.
- **Export Doctor** checks configuration and loadability; it does not run a full export (that remains the release step), and the templates check looks in the standard per-user templates folder.
- Editor dock interaction is verified by code inspection and a headless editor import; a hands-on editor session on Windows is still owed - see `QUALITY.md`.

## License

MIT - see `LICENSE`.

## Credits

Built for Godot 4. Uses only the Godot engine's own APIs; no third-party code.
