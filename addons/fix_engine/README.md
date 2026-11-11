# Fix Engine

Preview safe fixes from any tool report, and apply them only with explicit opt-in. Enable the addon, point the dock at a report JSON, and select **Preview fixes**.

```sh
godot --headless --path . --script res://addons/fix_engine/cli/fxe_cli.gd -- --report=res://demo/fix_engine/report.json
# Apply (writes backups first):
godot --headless --path . --script res://addons/fix_engine/cli/fxe_cli.gd -- --report=<report.json> --apply
```

Options: `--report=<path>`, `--apply`, `--backup-dir=<dir>` (default `res://reports/fix_engine/backup`), `--out=<dir>`, `--fail-on=no_safe_fix,apply_failed`. Exits 2 for findings selected by `--fail-on`, 1 on bad input, write failure or an unselected apply failure, 0 otherwise.

## Scope and limitations

- Allowlist only: `file_name` / `directory_name` renames to snake_case. Every other kind is reported as `no_safe_fix` and never touched.
- Preview is the default. `--apply` (or the dock checkbox) explicitly opts in. Sources and backups must be inside the project root; links and protected `.git`/`.godot` paths are refused. Existing destinations and backups are not overwritten. File backups preserve bytes and are checked with SHA-256; directory backups include hidden files. A failed directory backup may leave a partial backup to remove manually.
- Renames do **not** update references in scenes/scripts, have no editor undo, and cannot guarantee safety against concurrent external filesystem changes. Back up the project with version control and review references before applying. Backups are retained for manual recovery.
