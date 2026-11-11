# Dock accessibility and localization

The tools audit games; this page tracks auditing the tools themselves.

## What exists

- `addons/dock_a11y` provides a source-text heuristic for `tooltip_text`, `_on_run`, and `focus_mode`. It cannot prove that each control has a tooltip or is keyboard accessible.
- `tests/test_docks.gd` constructs docks, checks interactive controls for tooltips and keyboard focus, and invokes their run actions. The expanded suite is awaiting a successful CI run.
- `tests/editor/editor_verify/plugin.gd` clicks each dock's run action and saves screenshots; it does **not** prove the individual interactions below work.
- The new addons include English PO templates. Translation and screen-reader support across the suite remain unfinished.

## Editor interaction gaps

| Surface | Current evidence |
|---|---|
| Visual regression live viewport capture | Capture planning is tested; the editor session does not invoke the capture button or verify generated images. |
| Dialogue quest painted node graph | Layout is tested; the editor session does not check that the graph was painted correctly. |
| Responsive UI visual preview panes | The dock lists analysis results; multi-viewport preview panes are not implemented. |
| Whitebox snapping of a live selection | The dock audits scene text; a live-selection snapping action is not implemented. |

These gaps need actual interaction tests (and, where noted, implementation) before they can be marked verified. A generic successful dock click or screenshot is not evidence that these operations ran.
