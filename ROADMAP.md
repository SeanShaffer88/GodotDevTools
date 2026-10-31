# Development roadmap

This roadmap captures proposed tools, not a promise that every design is already implemented or verified. Work proceeds incrementally: each addon needs a pure core, thin editor dock and headless CLI, fixture-driven tests, documentation and honest limitations. A checked item means its initial implementation is verified; in-progress items remain unchecked. See each addon README and CI for verification status. Priorities may change as requirements are refined.

## Performance and rendering

- [ ] **Frame-Time Spike Investigator** — correlate frame spikes with scene changes, node counts, physics and markers.
- [ ] **GPU Budget and Overdraw Analyzer** — highlight overdraw and estimate fill-rate pressure at target resolutions.
- [ ] **Texture Memory and Streaming Planner** — estimate memory by platform and suggest compression, mipmaps and streaming.
- [ ] **Shader Variant Budget Manager** — inventory shader variants and flag compilation and memory risks.
- [ ] **Startup and Scene-Load Profiler** — break down startup and transition costs.
- [ ] **Object Pool Advisor** — find frequently spawned/freed objects and suggest pool candidates.
- [ ] **LOD and Visibility Range Planner** — flag missing LODs and problematic visibility distances.
- [ ] **Particle Budget Inspector** — estimate active particle counts against platform budgets.
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

- [ ] **Scene Change Impact Analyzer** — estimate downstream impact of changes to shared resources.
- [ ] **Scene Merge Conflict Assistant** — explain scene conflicts by node and property without silently rewriting files.
- [ ] **Resource Rename and Reference Assistant** — preview moves and affected references.
- [ ] **Asset Import Preset Auditor** — compare import settings to team-defined presets.
- [ ] **Project Cleanup Workbench** — collect unused candidates, duplicates and stale imports for review.
- [ ] **Naming and Folder Convention Enforcer** (in progress) — initial file/folder regex audit passed Godot 4.3/4.5 CI in PR #5; hands-on editor verification pending. Node, signal and group rules remain future work.
- [ ] **Scene Review Snapshot Generator** — generate reproducible scene inventories and diffs.
- [ ] **Editor Action Macro Recorder** — record and preview repeatable editor actions with undo support.
- [ ] **Node Property Drift Monitor** — compare node properties against team baselines.
- [ ] **Art-to-Engine Handoff Validator** — check model scale, orientation, materials, animation and collisions.

## Testing and reliability

- [ ] **Gameplay Scenario Test Builder** — compose repeatable actions and assertions.
- [ ] **Crash and Error Reproduction Packager** — bundle approved logs, settings and reproduction information.
- [ ] **Save Corruption and Recovery Tester** — inject invalid saves and verify recovery behavior.
- [ ] **State Transition Coverage Tracker** — report exercised and uncovered gameplay transitions.
- [ ] **Regression Test Prioritizer** — suggest tests based on changed files and dependencies.
- [ ] **Property-Based Gameplay Tester** — generate bounded input sequences to check invariants.
- [ ] **Resource Load Failure Simulator** — test fallbacks for missing, invalid or delayed resources.
- [ ] **Pause, Focus, and Lifecycle Tester** — exercise pause, focus, resize and suspend/resume.
- [ ] **Screenshot Baseline Review Queue** — review visual changes with metadata and approval history.
- [ ] **Performance Regression Gate** (in progress) — scalar baseline comparison with absolute/relative noise tolerances passed Godot 4.3/4.5 CI in PR #8; hands-on editor verification pending.

## Shipping, accessibility and live operations

- [ ] **Controller Glyph and Prompt Validator** — check device-specific prompts for input actions.
- [ ] **Color-Vision and Contrast Previewer** — preview color-vision differences and color-only cues.
- [ ] **Subtitle Timing and Readability Auditor** (in progress) — JSON cue timing, reading speed, line length and optional speaker checks passed Godot 4.3/4.5 CI in PR #6; hands-on editor verification pending. Safe-area and rendered-layout checks remain future work.
- [ ] **Platform Certification Checklist Runner** — track configurable platform-release requirements.
- [ ] **Privacy and Permissions Auditor** — inventory permissions, collection points and endpoints for review.
- [ ] **Offline and Poor-Connection Test Harness** — simulate outages, timeouts and interrupted requests.
- [ ] **Build Size Attribution Explorer** (in progress) — actual staged-directory file sizes by folder and extension, with budgets; Godot tests and editor verification pending. Archive-internal source attribution remains future work.
- [ ] **Demo-to-Release Content Guard** (in progress) — flag configurable placeholder and development markers for review; initial static scanner passed the Godot 4.3/4.5 CI gate in PR #4; hands-on editor verification remains.
- [ ] **Feature Flag and Rollout Simulator** (in progress) — offline deterministic rollout and prerequisite simulation passed Godot 4.3/4.5 CI in PR #9; hands-on editor verification pending.
- [ ] **Player Telemetry Schema Validator** (in progress) — local event and field checks plus explicit sensitive-field review passed Godot 4.3/4.5 CI in PR #7; hands-on editor verification pending.
