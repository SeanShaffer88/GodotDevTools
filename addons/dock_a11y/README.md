# Dock Accessibility Audit

Audit the editor docks themselves — tooltips, keyboard focus, run action and help text — instead of only auditing games. Enable the addon, enter a folder, and select **Audit docks**.

```sh
godot --headless --path . --script res://addons/dock_a11y/cli/dka_cli.gd -- --dir=res://addons --fail-on=missing_tooltip,missing_run_action
```

Options: `--dir=<path>`, `--out=<dir>`, `--fail-on=missing_tooltip,missing_run_action,keyboard_focus_unverified`. Exits 2 on `--fail-on`, 1 on bad input/write failure, 0 otherwise.

## Scope and limitations

- Text heuristic over `*_dock.gd` files: checks for `tooltip_text`, `_on_run`, and explicit `focus_mode`. It does not instantiate docks (the headless `tests/test_docks.gd` smoke test does that, including Tab-focus checks).
- `keyboard_focus_unverified` is info-level: buttons and line edits are focusable by default, so absence of an explicit `focus_mode` is not a failure.
- Dock strings are translated via `ui/translations/dock_strings.po` (see `docs/DOCK_A11Y.md`).
