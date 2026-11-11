# Suite Presets

Enable only the plugins you need. Enabling all 138 plugins slows editor startup and clutters the dock wall; presets fix that. Enable the addon, pick a preset in the dock, and select **Preview preset**.

```sh
godot --headless --path . --script res://addons/suite_presets/cli/spm_cli.gd -- --preset=mobile_perf
# Apply (backs up project.godot to project.godot.bak first):
godot --headless --path . --script res://addons/suite_presets/cli/spm_cli.gd -- --preset=ci_only --apply
```

Presets: `full`, `ci_only`, `mobile_perf`, `content`, `testing`. Options: `--preset=<name>`, `--project=<path>` (default `res://project.godot`), `--apply`, `--out=<dir>`, `--fail-on=unknown_preset`. Exits 2 on `--fail-on`, 1 on unknown preset/write failure, 0 otherwise.

## Scope and limitations

- Preview is read-only. `--apply` rewrites only the `[editor_plugins] enabled=` line and writes a `.bak` first.
- Presets list addon folder names; unknown folders in your project are disabled by packs (except `full`). Review the preview before applying.
- See `docs/ASSETLIB.md` for per-tool Asset Library publishing and `tools/assetlib/` for the generator.
