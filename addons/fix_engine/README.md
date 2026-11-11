# Fix Engine

Preview safe fixes from any tool report, and apply them only with explicit opt-in. Enable the addon, point the dock at a report JSON, and select **Preview fixes**.

```sh
godot --headless --path . --script res://addons/fix_engine/cli/fxe_cli.gd -- --report=res://demo/fix_engine/report.json
# Apply (writes backups first):
godot --headless --path . --script res://addons/fix_engine/cli/fxe_cli.gd -- --report=<report.json> --apply
```

Options: `--report=<path>`, `--apply`, `--backup-dir=<dir>` (default `res://reports/fix_engine/backup`), `--out=<dir>`, `--fail-on=no_safe_fix,apply_failed`. Exits 2 on `--fail-on`, 1 on bad input/write failure, 0 otherwise.

## Scope and limitations

- Allowlist only: `file_name` / `directory_name` renames to snake_case. Every other kind is reported as `no_safe_fix` and never touched.
- Preview is the default. `--apply` (or the dock checkbox) is the explicit opt-in; each file is backed up before its rename.
- Renames do not update references in scenes/scripts. Review references and version control before applying. This is a shared consumer of reports; no tool depends on it.
