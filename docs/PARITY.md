# GodotDevTools - Capability Parity

Scored from the test gate on Godot 4.3.stable. "Verified" = a test check or CLI gate run proves it on the fixture. "Partially Verified" = core logic verified headless; the editor-side experience still owes a hands-on session.

| Capability | Where | Status |
|---|---|---|
| Pixel diff with tolerance, diff count/fraction, changed-region box | visual_regression core | Verified |
| Highlight image (changed pixels in magenta) | visual_regression core + CLI file output | Verified |
| Baseline suite: pass/fail/missing capture/missing baseline, approval copy | visual_regression core | Verified (suite) / approval copy covered by code + suite round-trip in tests |
| Capture plan across resolutions | visual_regression core | Verified |
| Editor-side automatic capture from a running scene | - | Not built (documented limitation; roadmap) |
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
| Drawn node-graph view of dialogue | - | Not built (documented limitation; lists + simulation instead) |
| Seeded latency/jitter/loss/duplication/disconnect channel | network_sim core | Verified |
| Sync scenario + desync inspection (hash compare) | network_sim core + CLI | Verified |
| In-game proxy node | network_sim runtime | Partially Verified (wraps the verified core) |
| Project index (nodes, functions, variables, class names) | scene_search core | Verified |
| Rule-based natural-language query parsing + ranked, explained results | scene_search core + CLI | Verified |
| WCAG contrast ratio, tiny text, keyboard focus, colour-only checks | accessibility core | Verified |
| Export diagnosis: project essentials, autoloads, script load, presets, templates, features | export_doctor core + CLI | Verified |
| Every tool: editor dock with tooltips + offline help | ui/ docks | Partially Verified (headless import passes; hands-on editor session owed) |
| Every tool: headless CLI with JSON/Markdown reports and --fail-on gates | cli/ | Verified |
