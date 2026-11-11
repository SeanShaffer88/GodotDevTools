# Dock accessibility + localization

The tools audit games; this page tracks auditing the tools themselves.

## What exists

- `addons/dock_a11y` — text audit of `*_dock.gd` for `tooltip_text`, `_on_run`, and `focus_mode` (info-level). Run it over `res://addons` in CI via its CLI.
- `tests/test_docks.gd` — headless smoke test: instantiates every dock, checks every interactive control has a tooltip **and** is keyboard-focusable (`focus_mode != FOCUS_NONE`), then presses `_on_run` and checks output changes.
- `tests/editor/editor_verify/plugin.gd` — real-editor session now also checks the four previously *Partially Verified* surfaces (see below).
- Translations: each new addon ships `ui/translations/dock_strings.po` (msgid = English dock strings). Fill `msgstr` per locale and import the `.po` in your project; run `l10n_matrix` over the `.po` files to check completeness. Existing docks are English-only — translating all 138 is tracked as follow-up, starting with the five new docks.

## The four previously Partially Verified surfaces (now automated in editor session)

| Surface | Editor-session check |
|---|---|
| Visual regression live viewport capture | `capture_runner_live` — dock Capture section runs against an open scene, PNGs appear |
| Dialogue quest painted node graph | `dialogue_graph_painted` — GraphView draws nodes, screenshot non-blank |
| Responsive UI preview panes | `responsive_panes_drawn` — per-size panes render, output lists each size |
| Whitebox snapping of live selection | `whitebox_snap_live` — selection snaps to grid, output reports snapped transform |

Status: checks added; **Verified after the first green editor-session run** (per `PROJECT_RULES.md`). Until then they remain *Partially Verified* in `docs/PARITY.md`.

## Keyboard / screen-reader notes

- Every dock control has a tooltip (enforced by `test_docks.gd`).
- Buttons and line edits are focusable by default; `dock_a11y` flags docks that never set `focus_mode` as info, not failure.
- Output panes are `RichTextLabel` with `selection_enabled = true` so findings can be copied with the keyboard.
