## Offline, read-only file and directory naming audit.
extends RefCounted

const DEFAULT_PATTERN := "^[a-z][a-z0-9_]*$"
const EXCLUDED := ["addons", "reports", "visual_reports"]

func run(root: String = "res://", pattern: String = DEFAULT_PATTERN) -> Dictionary:
    var issues: Array = []
    var regex := RegEx.new()
    if pattern.is_empty() or regex.compile(pattern) != OK:
        issues.append(_issue("error", "invalid_pattern", root, "The naming pattern is empty or invalid.", "Provide a valid non-empty Godot regular expression."))
        return _result([], issues, pattern)
    var entries: Array = []
    if DirAccess.open(root) == null:
        issues.append(_issue("error", "scan_error", root, "Cannot open scan directory.", "Choose an existing readable directory."))
        return _result(entries, issues, pattern)
    _walk(root, entries, issues)
    entries.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
    return _check_entries(entries, regex, pattern, issues)

## Check explicit entries as well as filesystem scans; paths include res://.
func analyze(entries: Array, pattern: String = DEFAULT_PATTERN) -> Dictionary:
    var regex := RegEx.new()
    if pattern.is_empty() or regex.compile(pattern) != OK:
        return _result(entries, [_issue("error", "invalid_pattern", "", "The naming pattern is empty or invalid.", "Provide a valid non-empty Godot regular expression.")], pattern)
    return _check_entries(entries, regex, pattern, [])

func _walk(path: String, entries: Array, issues: Array) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        issues.append(_issue("error", "scan_error", path, "Cannot open directory.", "Check directory permissions and retry."))
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not name.begins_with(".") and name not in EXCLUDED:
            var full := path.path_join(name)
            var is_dir := dir.current_is_dir()
            entries.append({"path": full, "directory": is_dir})
            if is_dir:
                _walk(full, entries, issues)
        name = dir.get_next()
    dir.list_dir_end()

func _check_entries(entries: Array, regex: RegEx, pattern: String, issues: Array) -> Dictionary:
    for entry in entries:
        var path := str(entry.get("path", ""))
        var directory := bool(entry.get("directory", false))
        var name := path.get_file()
        var checked := name if directory else name.get_basename()
        if regex.search(checked) == null:
            var kind := "directory_name" if directory else "file_name"
            issues.append(_issue("warning", kind, path, "Name '%s' does not match %s." % [checked, pattern], "Rename after reviewing references and version control impact."))
    return _result(entries, issues, pattern)

func _result(entries: Array, issues: Array, pattern: String) -> Dictionary:
    return {"summary": {"entries": entries.size(), "issues": issues.size()}, "pattern": pattern, "issues": issues}

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Naming and Folder Convention Audit", "", "Summary: " + str(result["summary"]), "", "Pattern: `" + str(result["pattern"]) + "`", "", "## Findings"]
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
