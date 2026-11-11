# Dock accessibility and localization

The tools audit games; this page tracks auditing the tools themselves.

## What exists

- `addons/dock_a11y` provides a source-text heuristic for `tooltip_text`, `_on_run`, and `focus_mode`. It cannot prove that each control has a tooltip or is keyboard accessible.
- `tests/test_docks.gd` constructs docks, checks interactive controls for tooltips and keyboard focus, and invokes their run actions. The expanded suite passed in CI on commit `d430a6c`.
- The new addons include English PO templates. Translation and screen-reader support across the suite remain unfinished.

## Editor interaction coverage

The windowed editor harness now drives the actual controls below and records separate results; these new interaction checks are pending a CI run. A generic successful dock click or screenshot alone is not evidence that an interaction worked.

| Surface | Interaction under test | Scope |
|---|---|---|
| Visual regression capture | Click Capture now and inspect the dimensions and colored fixture content of all five PNGs. | Renderer and fixture dependent; not a visual baseline for real projects. |
| Dialogue graph | Run the check, confirm a missing-target graph and sample the painted warning outline. | Tests one fixture and the visible portion of the graph. |
| Responsive preview panes | Click Preview scene and check rendered fixture pixels and dimensions at three viewport sizes. | Scene instances can run `@tool` scripts; device safe areas and project window stretch are not simulated. |
| Whitebox selection snapping | Select a live 3D node, snap it with subdivisions, then test Undo and Redo. | Snaps local positions only; does not change rotations or save the scene. |

See the CI workflow results for the status of the current revision. Hosted runners use software renderers and do not replace hands-on hardware-GPU testing.
