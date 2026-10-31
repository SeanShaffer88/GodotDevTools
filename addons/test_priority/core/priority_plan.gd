## Prioritize explicitly mapped tests based on exact changed paths.
extends RefCounted

func analyze(mapping: Dictionary, changes: Dictionary) -> Dictionary:
    var issues: Array = []
    var rows: Array = []
    if typeof(mapping.get("paths")) != TYPE_DICTIONARY or typeof(changes.get("changed")) != TYPE_ARRAY:
        return _result(rows, [_issue("error", "input_error", "input", "Expected paths object and changed array.")])
    var paths: Dictionary = mapping["paths"]
    for path in paths:
        if typeof(paths[path]) != TYPE_ARRAY:
            issues.append(_issue("error", "invalid_mapping", str(path), "Mapping must contain an array of nonempty test paths."))
            continue
        for test in paths[path]:
            if typeof(test) != TYPE_STRING or str(test).is_empty():
                issues.append(_issue("error", "invalid_mapping", str(path), "Mapping must contain an array of nonempty test paths."))
    if not issues.is_empty():
        return _result(rows, issues)
    var scores := {}
    var visited := {}
    for path in changes["changed"]:
        if typeof(path) != TYPE_STRING or str(path).is_empty():
            issues.append(_issue("error", "invalid_path", "changed", "Changed paths must be nonempty strings."))
            continue
        if visited.has(path):
            continue
        visited[path] = true
        if not paths.has(path):
            issues.append(_issue("warning", "unmapped_path", path, "No tests mapped to this changed path."))
            continue
        var unique := {}
        for test in paths[path]:
            unique[test] = true
        for test in unique:
            if not scores.has(test):
                scores[test] = []
            scores[test].append(path)
    for test in scores:
        var reasons: Array = scores[test]
        reasons.sort()
        rows.append({"test": test, "score": reasons.size(), "changed_paths": reasons})
    rows.sort_custom(func(a, b): return a["score"] > b["score"] if a["score"] != b["score"] else a["test"] < b["test"])
    return _result(rows, issues)

func _issue(severity: String, kind: String, path: String, message: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": "Review changed paths and explicit test mappings."}

func _result(rows: Array, issues: Array) -> Dictionary:
    return {"summary": {"items": rows.size(), "issues": issues.size()}, "rows": rows, "issues": issues}

func run(first_path: String, second_path: String) -> Dictionary:
    var first := _read(first_path)
    var second := _read(second_path)
    if not first["ok"] or not second["ok"]:
        return _result([], [_issue("error", "input_error", "input", "Both inputs must be readable JSON objects.")])
    return analyze(first["data"], second["data"])

func _read(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return {"ok": false}
    return {"ok": true, "data": parser.data}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Regression Test Prioritizer", "", "Summary: " + str(result["summary"]), "", "## Results"]
    for row in result["rows"]:
        lines.append("- " + str(row))
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s" % [issue["kind"], issue["path"], issue["message"]])
    return "\n".join(lines) + "\n"
