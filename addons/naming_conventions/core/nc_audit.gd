## Offline, read-only file and directory naming audit.
extends RefCounted

const DEFAULT_PATTERN := "^[a-z][a-z0-9_]*$"
const DEFAULT_NODE_PATTERN := "^[A-Z][A-Za-z0-9]*$"
const EXCLUDED := ["addons", "reports", "visual_reports"]

func run(root: String = "res://", pattern: String = DEFAULT_PATTERN, symbols: bool = false, symbol_patterns: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var regex := RegEx.new()
    if pattern.is_empty() or regex.compile(pattern) != OK:
        issues.append(_issue("error", "invalid_pattern", root, "The naming pattern is empty or invalid.", "Provide a valid non-empty Godot regular expression."))
        return _result([], issues, pattern)
    var symbol_regexes := {}
    if symbols:
        for kind in ["node_name", "signal_name", "group_name"]:
            var default_pattern := DEFAULT_NODE_PATTERN if kind == "node_name" else DEFAULT_PATTERN
            var symbol_pattern := str(symbol_patterns.get(kind, default_pattern))
            var matcher := RegEx.new()
            if symbol_pattern.is_empty() or matcher.compile(symbol_pattern) != OK:
                issues.append(_issue("error", "invalid_pattern", kind, "Symbol pattern is empty or invalid.", "Provide a valid non-empty Godot regular expression."))
            else:
                symbol_regexes[kind] = matcher
        if not issues.is_empty():
            return _result([], issues, pattern)
    var entries: Array = []
    if DirAccess.open(root) == null:
        issues.append(_issue("error", "scan_error", root, "Cannot open scan directory.", "Choose an existing readable directory."))
        return _result(entries, issues, pattern)
    _walk(root, entries, issues)
    entries.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
    var result := _check_entries(entries, regex, pattern, issues)
    if symbols:
        _scan_symbols(entries, symbol_regexes, issues)
        result["summary"]["issues"] = issues.size()
    return result

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

## Text-only scan: scene node headers and literal signal/group declarations.
func _scan_symbols(entries: Array, patterns: Dictionary, issues: Array) -> void:
    var node := RegEx.new()
    node.compile("^\\[node[ \\t]+name=\"([^\"]+)\"")
    var groups := RegEx.new()
    groups.compile("(?:^|[ \\t])groups=\\[([^\\]]*)\\]")
    var quoted := RegEx.new()
    quoted.compile("\"([^\"]+)\"")
    var signal_declaration := RegEx.new()
    signal_declaration.compile("^[ \\t]*signal[ \\t]+([A-Za-z_][A-Za-z0-9_]*)")
    var group_call := RegEx.new()
    group_call.compile("^[ \\t]*(?:[A-Za-z_][A-Za-z0-9_]*\\.)?add_to_group[ \\t]*\\([ \\t]*[\"']([^\"']+)[\"']")
    for entry in entries:
        if bool(entry.get("directory", false)):
            continue
        var path := str(entry["path"])
        var ext := path.get_extension().to_lower()
        if ext not in ["tscn", "gd"]:
            continue
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            issues.append(_issue("error", "scan_error", path, "Cannot read file for symbol audit.", "Check file permissions and retry."))
            continue
        var lines := file.get_as_text().split("\n")
        for index in range(lines.size()):
            var line := str(lines[index]).strip_edges()
            var location := "%s:%d" % [path, index + 1]
            if ext == "tscn":
                var match_node := node.search(line)
                if match_node != null:
                    _check_symbol("node_name", match_node.get_string(1), location, patterns, issues)
                    var group_match := groups.search(line)
                    if group_match != null:
                        for group in quoted.search_all(group_match.get_string(1)):
                            _check_symbol("group_name", group.get_string(1), location, patterns, issues)
            elif not line.begins_with("#"):
                var signal_match := signal_declaration.search(line)
                if signal_match != null:
                    _check_symbol("signal_name", signal_match.get_string(1), location, patterns, issues)
                var group_match := group_call.search(line)
                if group_match != null:
                    _check_symbol("group_name", group_match.get_string(1), location, patterns, issues)

func _check_symbol(kind: String, name: String, location: String, patterns: Dictionary, issues: Array) -> void:
    var matcher: RegEx = patterns[kind]
    if matcher.search(name) == null:
        issues.append(_issue("warning", kind, location, "Name '%s' does not match %s." % [name, matcher.get_pattern()], "Review references before renaming this symbol."))

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
