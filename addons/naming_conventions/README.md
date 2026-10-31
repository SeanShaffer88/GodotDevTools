# Naming and Folder Convention Enforcer

A read-only audit of file basenames and directory names against a configurable Godot regular expression. Enable the addon in Project Settings → Plugins, enter a directory and pattern in the dock, and select **Audit names**. The default `^[a-z][a-z0-9_]*$` enforces lowercase snake-style names starting with a letter.

```sh
godot --headless --path . --script res://addons/naming_conventions/cli/nc_cli.gd -- \
  --dir=res://demo/naming --fail-on=file_name,directory_name
```

The CLI accepts `--dir=<path>` (default `res://`), `--pattern=<Godot regex>`, `--out=<dir>` (default `res://reports/naming_conventions`), and `--fail-on=file_name,directory_name` or `--fail-on=issues`. It writes JSON and Markdown reports. It exits 2 for selected naming findings, 1 for an invalid pattern, scan failure, or report-write failure, and 0 otherwise.

## Scope and limitations

The regex is searched against each filename without its last extension and each directory name. Anchor the expression with `^` and `$` to require a full-name match. Hidden entries, `addons`, `reports`, and `visual_reports` are skipped at every level. This initial implementation does **not** check scene node names, class names, signals, groups, or file contents; it does not rename anything. Review references and version-control implications before renaming. Large-project performance, Godot execution, and the editor dock require verification.
