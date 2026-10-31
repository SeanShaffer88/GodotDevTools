# AI_USAGE.md - GodotDevTools guide for AI agents

This file has two halves. The first is a **pasteable project prompt**: drop it
into any AI assistant that will work in this repo, or in a game project that
uses these tools. The second half is the **stable reference** the prompt points
at - the exact file map, what to inspect and in which order, and CLI examples for the original tools. For the full list and options, see the
[root README](README.md) and the individual addon READMEs.

Facts below are taken from the code itself (CLI bodies, `plugin.cfg` files,
[test suite](tests/run_tests.sh)), not from prose that could drift. When code
and documentation disagree, the code wins and the docs get fixed.

## The prompt (copy everything inside the box)

```text
You are working with GodotDevTools: thirty independent developer tools for
Godot 4 games, in a repo that is itself a Godot demo/test project. Everything
is offline, deterministic, MIT-licensed GDScript with no third-party
dependencies. The previous 29-tool baseline passed CI on Godot 4.3-stable and 4.5-stable;
run the current full gate before claiming the new addon is verified.

WHERE THE TOOLS ARE
- addons/<tool>/ for: accessibility, asset_health, dialogue_quest,
  export_doctor, network_sim, responsive_ui, scene_search, time_machine,
  visual_regression and the additional addons listed in README.md.
  Each folder is independently installable.
- Inside each tool: plugin.cfg + plugin.gd (editor entry point), core/ (the
  ONE operation - all checking logic, no editor APIs), ui/ (editor dock, a
  thin shell), cli/ (headless runner, a thin shell), and for tools with in-game functionality a runtime/ node you place in a game scene.
- demo/ is a fixture project containing one deliberate problem per tool.
  tests/ holds one suite per tool plus run_tests.sh, the full gate.
  docs/PARITY.md is the capability matrix, QUALITY.md the scorecard,
  PROJECT_RULES.md the frozen architecture rules, CONTRIBUTING.md what a
  change needs before it can merge, CHANGELOG.md the history.

WHAT TO INSPECT BEFORE ANSWERING
1. PROJECT_RULES.md - the frozen core/ui/cli layout and the special rules
   (quarantine unparsable files, seeded randomness, explained search hits).
2. The tool's core/ file - the authoritative behaviour. Every check, message
   and fix string lives there; docks and CLIs add no logic of their own.
3. The tool's cli/ script header comment - the authoritative option list.
4. The tool's demo/ fixture case - the concrete problem each check must catch.
5. docs/PARITY.md - what is Verified vs Partially Verified. Never claim more
   than the matrix says.

HOW TO APPLY THE TOOLS
- Full gate (needs a Godot 4.3+ binary): sh tests/run_tests.sh /path/to/godot
  It ends with ALL GATE CHECKS PASSED or fails loudly. CI runs the same script
  on every push/PR (.github/workflows/tests.yml) on 4.3 and 4.5 headless.
- One tool headless, from the project root:
  godot --headless --path . --script res://addons/<tool>/cli/<cli>.gd -- [options]
  Every CLI writes <name>.json + <name>.md under --out (default
  res://reports/<tool>; visual_regression defaults to res://visual_reports),
  prints a summary line plus every finding, and exits 0 clean or 2 when a
  --fail-on gate trips. Use exit 2 as the CI failure signal.
- Per-tool options and fail-on kinds are the table in AI_USAGE.md
  ("Headless CLI reference"); the CLI header comments carry the same list.
- In the editor: enable the plugin under Project Settings -> Plugins, press
  Run check in its dock; "?" repeats the offline help. visual_regression's
  dock also has Capture now (one-click screenshots into res://visual_current),
  and dialogue_quest's dock draws the selected dialogue's branch graph.
- In a game: time_machine's runtime/gstm_node.gd records inputs + state
  snapshots every physics frame (rewind_to(frame), sessions save as JSON);
  network_sim's runtime/mns_proxy.gd routes test packets with inspector-set
  latency/jitter/loss and emits message_delivered.

RULES THAT MUST NOT BREAK
- New checking logic goes in core/ only; docks, CLIs and tests stay thin.
- No tool depends on another tool. No network use, ever. Randomness is seeded.
- Binary or unparsable files are quarantined and reported, never guessed.
- Every promised check has a demo/ fixture case and a tests/ check
  (the coverage floor). Every finding carries a plain-words fix.
- "Verified" means a test check or CI run proves it. Editor-rendered surfaces
  CI cannot exercise are Partially Verified until clicked through by a human.
- Every change gets a CHANGELOG.md entry under [Unreleased].
```

## Where the tools are

Twenty-nine addons, one folder each, no cross-dependencies. The original nine
are mapped below; see the [root README](README.md) for all thirty.

| Tool (plugin name) | Core - the operation | Dock | CLI | Runtime |
|---|---|---|---|---|
| Visual Regression Testing | [vrt_compare.gd](addons/visual_regression/core/vrt_compare.gd), [vrt_baselines.gd](addons/visual_regression/core/vrt_baselines.gd), [vrt_capture.gd](addons/visual_regression/core/vrt_capture.gd) | [vrt_dock.gd](addons/visual_regression/ui/vrt_dock.gd) | [vrt_cli.gd](addons/visual_regression/cli/vrt_cli.gd) | - |
| Game-State Time Machine | [gstm_recorder.gd](addons/time_machine/core/gstm_recorder.gd) | [gstm_dock.gd](addons/time_machine/ui/gstm_dock.gd) | [gstm_cli.gd](addons/time_machine/cli/gstm_cli.gd) | [gstm_node.gd](addons/time_machine/runtime/gstm_node.gd) |
| Responsive UI Previewer | [ruip_evaluator.gd](addons/responsive_ui/core/ruip_evaluator.gd) | [ruip_dock.gd](addons/responsive_ui/ui/ruip_dock.gd) | [ruip_cli.gd](addons/responsive_ui/cli/ruip_cli.gd) | - |
| Asset Health Dashboard | [ahd_scanner.gd](addons/asset_health/core/ahd_scanner.gd) | [ahd_dock.gd](addons/asset_health/ui/ahd_dock.gd) | [ahd_cli.gd](addons/asset_health/cli/ahd_cli.gd) | - |
| Dialogue and Quest Debugger | [dqd_graph.gd](addons/dialogue_quest/core/dqd_graph.gd), [dqd_layout.gd](addons/dialogue_quest/core/dqd_layout.gd) | [dqd_dock.gd](addons/dialogue_quest/ui/dqd_dock.gd) | [dqd_cli.gd](addons/dialogue_quest/cli/dqd_cli.gd) | - |
| Multiplayer Network Simulator | [mns_channel.gd](addons/network_sim/core/mns_channel.gd) | [mns_dock.gd](addons/network_sim/ui/mns_dock.gd) | [mns_cli.gd](addons/network_sim/cli/mns_cli.gd) | [mns_proxy.gd](addons/network_sim/runtime/mns_proxy.gd) |
| Natural-Language Scene Search | [nlss_search.gd](addons/scene_search/core/nlss_search.gd) | [nlss_dock.gd](addons/scene_search/ui/nlss_dock.gd) | [nlss_cli.gd](addons/scene_search/cli/nlss_cli.gd) | - |
| Automated Accessibility Checker | [a11y_checker.gd](addons/accessibility/core/a11y_checker.gd) | [a11y_dock.gd](addons/accessibility/ui/a11y_dock.gd) | [a11y_cli.gd](addons/accessibility/cli/a11y_cli.gd) | - |
| Build and Export Doctor | [bed_doctor.gd](addons/export_doctor/core/bed_doctor.gd) | [bed_dock.gd](addons/export_doctor/ui/bed_dock.gd) | [bed_cli.gd](addons/export_doctor/cli/bed_cli.gd) | - |

Each addon folder also has its own [README](addons/visual_regression/README.md)
with install steps and tool-specific help.

## What to inspect, in order

Orientation files, cheapest signal first:

1. [PROJECT_RULES.md](PROJECT_RULES.md) - the frozen foundation (core/ui/cli
   per tool, no cross-dependencies) and the special rules: quarantine
   unparsable files, seeded simulation randomness, search results always
   state why they matched, versions claimed only after a test run.
2. [README.md](README.md) - human overview, install, limitations list.
3. [docs/PARITY.md](docs/PARITY.md) - capability-by-capability Verified /
   Partially Verified / built-with-status matrix. This bounds what may be
   claimed.
4. [QUALITY.md](QUALITY.md) - current gate count and scorecard
   (the file is the source of truth).
5. [CHANGELOG.md](CHANGELOG.md) - what changed recently, under [Unreleased].
6. [tests/run_tests.sh](tests/run_tests.sh) - the full gate script; reading it
   shows exactly which CLI invocations and exit-code-2 paths are enforced.

The demo fixture - one deliberate problem per tool, all under [demo/](demo/):

| Fixture | Deliberate problem | Tool it feeds |
|---|---|---|
| [demo/visual/](demo/visual/) | `menu__320x240.png` differs from its baseline by exactly 16 pixels; `extra__320x240.png` has no baseline; the `hud` pair is identical | visual_regression |
| [demo/time_machine/example_session.json](demo/time_machine/example_session.json) | a valid recorded session (frame order, inputs) | time_machine |
| [demo/ui/hud.tscn](demo/ui/hud.tscn) | HUD that overflows small screens; tiny low-contrast label; keyboard-unreachable button | responsive_ui, accessibility |
| [demo/assets/](demo/assets/) | `big.png` oversized texture; `hero_copy.png` byte-identical duplicate of `hero.png`; `orphan.png` referenced by nothing | asset_health |
| [demo/dialogue/story.json](demo/dialogue/story.json) | choice pointing at missing `ghost_node`; unreachable `secret_room`; condition-gated choices (`met_guard`, `gold`); quest requiring nonexistent `crown_jewel`; `cycle_a`/`cycle_b` dependency circle | dialogue_quest |
| [demo/enemy/enemy.tscn](demo/enemy/enemy.tscn), [demo/level/door.tscn](demo/level/door.tscn) | a patrol-state enemy and a door interaction, phrased so plain-words queries find them | scene_search |
| [export_presets.cfg](export_presets.cfg) (repo root) | preset pointing at an icon file that does not exist | export_doctor |
| network cases live in the test suites ([tests/test_mns.gd](tests/test_mns.gd)) | seeded lossy/disconnected channels, reproducible from the seed | network_sim |

## How to apply the tools

### Headless CLI reference

Invocation shape (same for all tools, from the project root):

```sh
godot --headless --path . --script res://addons/<tool>/cli/<cli>.gd -- [options]
```

Contract every CLI shares (from the code, for the original nine listed below):

- Writes `<name>.json` and `<name>.md` reports into `--out=<dir>`
  (`--format=json,md` selects which; both by default).
- Prints a summary line (`VRT summary: {...}`) and every finding
  (`AHD [warning] ...`).
- Exits **0** clean, **2** when any `--fail-on` gate trips. That exit 2 is
  the CI signal; `run_tests.sh` asserts it on five of the tools.

Per-tool options, defaults and gate kinds:

- **visual_regression** - [vrt_cli.gd](addons/visual_regression/cli/vrt_cli.gd):
  `--baseline=` (default `res://visual_baselines`), `--current=` (default
  `res://visual_current`), `--out=` (default `res://visual_reports`),
  `--tolerance=<0-255>` (default 8 per channel), `--fail-fraction=<f>`
  (default 0.001), `--fail-on=visual_diff,missing_capture,missing_baseline`.
  Failing pairs also write `<name>.highlight.png` (changed pixels in magenta)
  into the out dir.
- **time_machine** - [gstm_cli.gd](addons/time_machine/cli/gstm_cli.gd):
  `--session=<json>` (default `res://time_machine_session.json`),
  `--fail-on=errors`. Verifies a recorded session: parse, frame order, input
  count.
- **responsive_ui** - [ruip_cli.gd](addons/responsive_ui/cli/ruip_cli.gd):
  `--fail-on=issues`. Evaluates project UI scenes across the 9 screen presets.
- **asset_health** - [ahd_cli.gd](addons/asset_health/cli/ahd_cli.gd):
  `--big-texture=<px>` (a texture is oversized above px x px pixels),
  `--fail-on=oversized_texture,duplicate,unused,import_inconsistent,slow_load`.
- **dialogue_quest** - [dqd_cli.gd](addons/dialogue_quest/cli/dqd_cli.gd):
  `--file=<json>` (repeatable; omit to auto-find all dialogue/quest JSON in
  the project), `--simulate=<dialogue>:<pick,pick,...>` (picks are choice
  indexes at each stop), `--state='{"var": value}'` (inline JSON the
  simulation's conditions evaluate against),
  `--fail-on=issues,missing_target,bad_start`.
- **network_sim** - [mns_cli.gd](addons/network_sim/cli/mns_cli.gd):
  `--latency=<ticks>`, `--jitter=<ticks>`, `--loss=<0..1>`,
  `--disconnect=<from>-<to>`, `--ticks=<n>` (default 180),
  `--fail-on=issues,packet_loss`. Seeded: the same options reproduce the same
  bad network.
- **scene_search** - [nlss_cli.gd](addons/scene_search/cli/nlss_cli.gd):
  `--query="<plain words>"` (default: `find enemies that use a patrol state`).
  No tool-specific gate kinds; every result prints why it matched.
- **accessibility** - [a11y_cli.gd](addons/accessibility/cli/a11y_cli.gd):
  `--fail-on=errors,tiny_text,low_contrast,no_keyboard_focus`.
- **export_doctor** - [bed_cli.gd](addons/export_doctor/cli/bed_cli.gd):
  `--fail-on=errors`. Run before a release build: exit 2 means do not ship.

The original nine also accept `--out=<dir>` (defaults: `res://reports/<tool>`, except
visual_regression's `res://visual_reports`) and `--format=json,md`. Generic
`--fail-on=errors` (any error-severity finding) and `--fail-on=issues` (any
finding) work everywhere.

Worked examples that run against this repo's fixture:

```sh
# must exit 2 - the menu pair differs from its baseline
godot --headless --path . --script res://addons/visual_regression/cli/vrt_cli.gd -- \
  --baseline=res://demo/visual/baselines --current=res://demo/visual/current --fail-on=visual_diff

# must exit 2 - hero_copy.png duplicates hero.png
godot --headless --path . --script res://addons/asset_health/cli/ahd_cli.gd -- --fail-on=duplicate

# play the tavern dialogue as a broke player who has met the guard
godot --headless --path . --script res://addons/dialogue_quest/cli/dqd_cli.gd -- \
  --simulate=tavern:0,0 --state='{"met_guard": true, "gold": 2}'

# deterministic bad network: 5-tick latency, 10% loss, disconnect ticks 60-90
godot --headless --path . --script res://addons/network_sim/cli/mns_cli.gd -- \
  --latency=5 --jitter=1 --loss=0.1 --disconnect=60-90 --fail-on=packet_loss
```

### In the editor

Enable a plugin under **Project -> Project Settings -> Plugins**; its dock
appears on the editor's right side with **Run check**, a results list and a
`?` offline help button. Two docks do more than run the check:

- **Visual Regression**: the Capture section (scene list, output folder,
  **Capture now**) is the one-click shutter - it instantiates each scene in an
  offscreen viewport at the standard resolutions and saves
  `<scene>__<width>x<height>.png` where the compare run reads it. Needs the
  editor's renderer; it never runs headless.
- **Dialogue and Quest**: a dialogue picker above a drawn branch graph -
  layered boxes (green outline = start, blue = marked ending, orange = flagged
  by the report, red dashed ghost = a choice target that does not exist),
  arrows with `[if]` on conditional choices.

In a game under test, two runtime nodes wrap verified cores:
[gstm_node.gd](addons/time_machine/runtime/gstm_node.gd) (register Callables
that snapshot/restore state as a Dictionary; it records every physics frame;
`rewind_to(frame)`; sessions save to JSON) and
[mns_proxy.gd](addons/network_sim/runtime/mns_proxy.gd) (route test packets
through it; set latency/jitter/loss in the inspector; deliveries arrive on its
`message_delivered` signal).

### In CI

The pattern is: run a CLI, treat exit 2 as failure, archive the reports.
This repo's own [.github/workflows/tests.yml](.github/workflows/tests.yml) is
the worked example - it runs [tests/run_tests.sh](tests/run_tests.sh) (import
check, thirty suites, CLI smokes, and exit-code-2 gate assertions) headless on
Godot 4.3-stable and 4.5-stable on pushes to main and pull requests, and uploads
`reports/` + `visual_reports/` as artifacts. A minimal game-project pipeline:

```yaml
- run: godot --headless --path . --script res://addons/export_doctor/cli/bed_cli.gd -- --fail-on=errors
- run: godot --headless --path . --script res://addons/asset_health/cli/ahd_cli.gd -- --fail-on=duplicate,oversized_texture
- run: godot --headless --path . --script res://addons/accessibility/cli/a11y_cli.gd -- --fail-on=errors
```

### In your own game project (install)

Copy one or more `addons/<tool>` folders into the project's `addons/` folder
and enable them, or unzip a release asset from
[GitHub Releases](https://github.com/SeanShaffer88/GodotDevTools/releases)
(one zip per tool, or the suite) into the project root. The CLIs work as soon
as the files are in place - enabling the plugin is only needed for the docks.

## Rules for changing this repo

The full contract is [CONTRIBUTING.md](CONTRIBUTING.md); the short version an
AI agent must follow:

- Checking logic lives in `core/` only; docks/CLIs/tests stay thin shells.
- Every new or changed check needs a [demo/](demo/) fixture case and a check
  in the matching [tests/](tests/) suite (the coverage floor).
- Run `sh tests/run_tests.sh /path/to/godot` - or rely on CI - and keep it
  green on the 4.3 job before proposing a merge.
- Status labels stay honest per [docs/PARITY.md](docs/PARITY.md): Verified
  only with a test run behind it.
- Add a [CHANGELOG.md](CHANGELOG.md) entry under `[Unreleased]`.
- Releases are cut from `v*` tags by
  [.github/workflows/release.yml](.github/workflows/release.yml), which
  re-runs the gate before building zips - never hand-make release artifacts.
