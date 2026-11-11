# Suite Presets

Enable only the plugins you need. Enabling all 138 plugins slows editor startup and clutters the dock wall; presets fix that. Enable the addon, pick a preset in the dock, and select **Preview preset**.

```sh
godot --headless --path . --script res://addons/suite_presets/cli/spm_cli.gd -- --preset=mobile_perf
# Apply (backs up project.godot to project.godot.bak first):
godot --headless --path . --script res://addons/suite_presets/cli/spm_cli.gd -- --preset=ci_only --apply
```

Presets: `full`, `ci_only`, `mobile_perf`, `content`, `testing`. Options: `--preset=<name>`, `--project=<path>` (default `res://project.godot`), `--apply`, `--out=<dir>`, `--fail-on=unknown_preset`. Exits 2 on `--fail-on`, 1 on unknown preset/write failure, 0 otherwise.

## Scope and limitations

- Preview is read-only. `--apply` verifies a byte-for-byte `.bak` before rewriting the `[editor_plugins] enabled` setting; it refuses to overwrite an existing backup. Restore the backup manually if a write fails. Multiline settings, mixed line endings and duplicate plugin sections are refused rather than rewritten.
- Presets enumerate the addon folders next to the selected `--project` file; the directory must exist. Unknown folders in your project are disabled by packs (except `full`). Review the preview before applying. The operation does not offer editor undo.
- See `docs/ASSETLIB.md` for per-tool Asset Library publishing and `tools/assetlib/` for the generator.
