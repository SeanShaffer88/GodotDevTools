## Read-only inventory of the actual files in an unpacked build directory.
extends RefCounted

func run(root: String, max_file_bytes: int = 0, max_total_bytes: int = 0) -> Dictionary:
    if max_file_bytes < 0 or max_total_bytes < 0:
        return _result([], {}, {}, 0, [_issue("error", "invalid_budget", root, "Byte budgets must be non-negative.", "Use zero to disable a budget.")])
    var files: Array = []
    var issues: Array = []
    _walk(root, "", files, issues)
    return analyze(files, max_file_bytes, max_total_bytes, issues)

func _walk(root: String, relative: String, files: Array, issues: Array) -> void:
    var current := root if relative.is_empty() else root.path_join(relative)
    var dir := DirAccess.open(current)
    if dir == null:
        issues.append(_issue("error", "scan_error", current, "Cannot open directory.", "Choose an existing readable build directory."))
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name != "." and name != "..":
            var path := name if relative.is_empty() else relative.path_join(name)
            if dir.is_link(name):
                issues.append(_issue("warning", "skipped_link", path, "Symbolic link or junction was not followed.", "Inspect the link target separately if it is part of the build."))
            elif dir.current_is_dir():
                _walk(root, path, files, issues)
            else:
                var file := FileAccess.open(root.path_join(path), FileAccess.READ)
                if file == null:
                    issues.append(_issue("error", "scan_error", path, "Cannot read file.", "Check permissions and retry the scan."))
                else:
                    files.append({"path": path, "bytes": file.get_length()})
        name = dir.get_next()
    dir.list_dir_end()

## File inventory rows use relative paths and integer byte counts.
func analyze(files: Array, max_file_bytes: int = 0, max_total_bytes: int = 0, initial_issues: Array = []) -> Dictionary:
    var issues: Array = initial_issues.duplicate(true)
    var groups := {}
    var extensions := {}
    var rows: Array = []
    var total := 0
    if max_file_bytes < 0 or max_total_bytes < 0:
        issues.append(_issue("error", "invalid_budget", "budgets", "Byte budgets must be non-negative.", "Use zero to disable a budget."))
        return _result(rows, groups, extensions, total, issues)
    for entry in files:
        if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("path")) != TYPE_STRING or str(entry.get("path", "")).is_empty() or typeof(entry.get("bytes")) != TYPE_INT or int(entry.get("bytes", -1)) < 0:
            issues.append(_issue("error", "invalid_entry", "inventory", "File entry needs a non-empty path and non-negative integer byte count.", "Correct the inventory input."))
            continue
        var path := str(entry["path"])
        var size := int(entry["bytes"])
        var group := path.get_slice("/", 0) if path.contains("/") else "(root)"
        var ext := path.get_extension().to_lower()
        if ext.is_empty():
            ext = "(no extension)"
        groups[group] = int(groups.get(group, 0)) + size
        extensions[ext] = int(extensions.get(ext, 0)) + size
        total += size
        rows.append({"path": path, "bytes": size, "group": group, "extension": ext})
        if max_file_bytes > 0 and size > max_file_bytes:
            issues.append(_issue("warning", "file_budget", path, "File is %d bytes; limit is %d." % [size, max_file_bytes], "Review the file or update its budget."))
    rows.sort_custom(func(a, b): return a["bytes"] > b["bytes"] if a["bytes"] != b["bytes"] else a["path"] < b["path"])
    if max_total_bytes > 0 and total > max_total_bytes:
        issues.append(_issue("warning", "total_budget", "build", "Scanned files total %d bytes; limit is %d." % [total, max_total_bytes], "Review build contents or update its budget."))
    return _result(rows, groups, extensions, total, issues)

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func _result(rows: Array, groups: Dictionary, extensions: Dictionary, total: int, issues: Array) -> Dictionary:
    return {"summary": {"files": rows.size(), "bytes": total, "issues": issues.size()}, "files": rows, "groups": groups, "extensions": extensions, "issues": issues}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Build Size Attribution", "", "Summary: " + str(result["summary"]), "", "## Largest files"]
    for row in result["files"]:
        lines.append("- `%s`: %d bytes" % [row["path"], row["bytes"]])
    lines.append_array(["", "## Top-level folders", ""])
    var groups: Array = result["groups"].keys()
    groups.sort()
    for group in groups:
        lines.append("- `%s`: %d bytes" % [group, result["groups"][group]])
    lines.append_array(["", "## Extensions", ""])
    var extensions: Array = result["extensions"].keys()
    extensions.sort()
    for ext in extensions:
        lines.append("- `%s`: %d bytes" % [ext, result["extensions"][ext]])
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
