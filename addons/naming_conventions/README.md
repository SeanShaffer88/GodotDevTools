# Naming and Folder Convention Enforcer

A read-only audit of file basenames and directory names against a configurable Godot regular expression. Enable the addon in Project Settings → Plugins, enter a directory and pattern in the dock, and select **Audit names**. The default `^[a-z][a-z0-9_]*$` enforces lowercase snake-style names starting with a letter.

```sh
godot --headless --path . --script res://addons/naming_conventions/cli/nc_cli.gd -- \
  --dir=res://demo/naming_symbols --symbols --fail-on=node_name,signal_name,group_name
```

The optional `--symbols` scan checks scene node names, scene group declarations, GDScript signal declarations, and literal `add_to_group("name")` statements. Defaults are `^[A-Z][A-Za-z0-9]*$` for nodes and `^[a-z][a-z0-9_]*$` for signals and groups. Override with `--node-pattern=`, `--signal-pattern=` and `--group-pattern=`. The dock offers the optional symbol scan using these defaults. Symbol findings include file and line.

The CLI also accepts `--dir=<path>` (default `res://`), `--pattern=<Godot regex>` for files/folders, `--out=<dir>` (default `res://reports/naming_conventions`), and comma-separated `--fail-on` kinds or `issues`. It writes JSON and Markdown reports. It exits 2 for selected naming findings, 1 for invalid patterns, scan failures, or report-write failures, and 0 otherwise.

## Scope and limitations

Patterns are searched, not automatically anchored: use `^` and `$` to require full-name matches. File checks use the basename without its last extension. Hidden entries, `addons`, `reports`, and `visual_reports` are skipped at every level within the scan root.

Godot metadata sidecar **files** with compound names such as `texture.png.import` or `player.gd.uid` are excluded from both filesystem scans and explicit `analyze()` entries, including the entry count. Their source files are checked independently; sidecar-named directories and files with only one extension, such as `notes.import`, are still checked. The last extension is matched case-insensitively. This is a filename heuristic: orphaned sidecars and deliberately authored files with the same compound suffixes are also excluded, without inspecting their contents.

Symbol scanning is a **text heuristic**, not a GDScript or scene parser: it recognizes conventional single-line `.tscn` node headers with quoted names and `groups=[...]`, GDScript `signal` declarations, and literal group calls at the start of a statement (optionally preceded by a simple object name). Dynamic group names, class names, inherited nodes, alternate syntax, escaped strings, multiline declarations, C# and code inside expressions may be missed. Multi-line GDScript strings can produce false positives. It does not instantiate scenes or rename anything. Review references and version-control implications before renaming. File/folder and symbol fixtures passed Godot 4.3/4.5 CI before the sidecar change; a hands-on dock session and production-scale validation are still outstanding.
