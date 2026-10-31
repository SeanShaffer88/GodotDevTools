## Prioritize explicitly mapped tests based on exact changed paths.
extends RefCounted

## Optional graph edges point from a dependent file to its dependency.
## The reverse walk records a deterministic shortest chain per mapped dependent.
func analyze(mapping: Dictionary, changes: Dictionary, graph: Dictionary = {}) -> Dictionary:
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
    var reverse := {}
    if not graph.is_empty():
        if typeof(graph.get("edges")) != TYPE_ARRAY:
            issues.append(_issue("error", "invalid_graph", "graph.edges", "Graph must contain an edges array."))
        else:
            for edge in graph["edges"]:
                if typeof(edge) != TYPE_DICTIONARY or typeof(edge.get("from")) != TYPE_STRING or typeof(edge.get("to")) != TYPE_STRING or str(edge.get("from", "")).is_empty() or str(edge.get("to", "")).is_empty():
                    issues.append(_issue("error", "invalid_graph", "graph.edges", "Each edge requires nonempty from and to paths."))
                    continue
                var dependency: String = edge["to"]
                var dependent: String = edge["from"]
                if not reverse.has(dependency):
                    reverse[dependency] = []
                if dependent not in reverse[dependency]:
                    reverse[dependency].append(dependent)
            for dependency in reverse:
                reverse[dependency].sort()
    if not issues.is_empty():
        return _result(rows, issues)
    var scores := {}
    var evidence := {}
    var visited_changes := {}
    for path in changes["changed"]:
        if typeof(path) != TYPE_STRING or str(path).is_empty():
            issues.append(_issue("error", "invalid_path", "changed", "Changed paths must be nonempty strings."))
            continue
        if visited_changes.has(path):
            continue
        visited_changes[path] = true
        var chains := {}
        chains[path] = [path]
        var queue: Array = [path]
        var cursor := 0
        var matched := false
        while cursor < queue.size():
            var affected: String = queue[cursor]
            cursor += 1
            if paths.has(affected):
                var unique := {}
                for test in paths[affected]:
                    unique[test] = true
                for test in unique:
                    matched = true
                    if not scores.has(test):
                        scores[test] = {}
                        evidence[test] = []
                    scores[test][path] = true
                    evidence[test].append({"changed": path, "mapped_path": affected, "dependency_chain": chains[affected].duplicate()})
            for dependent in reverse.get(affected, []):
                if not chains.has(dependent):
                    chains[dependent] = chains[affected].duplicate()
                    chains[dependent].append(dependent)
                    queue.append(dependent)
        if not matched:
            issues.append(_issue("warning", "unmapped_path", path, "No tests mapped to this changed path or its known dependents."))
    for test in scores:
        var reasons: Array = scores[test].keys()
        reasons.sort()
        rows.append({"test": test, "score": reasons.size(), "changed_paths": reasons, "evidence": evidence[test]})
    rows.sort_custom(func(a, b): return a["score"] > b["score"] if a["score"] != b["score"] else a["test"] < b["test"])
    return _result(rows, issues)

func _issue(severity: String, kind: String, path: String, message: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": "Review changed paths and explicit test mappings."}

func _result(rows: Array, issues: Array) -> Dictionary:
    return {"summary": {"items": rows.size(), "issues": issues.size()}, "rows": rows, "issues": issues}

func run(first_path: String, second_path: String, graph_path: String = "") -> Dictionary:
    var first := _read(first_path)
    var second := _read(second_path)
    if not first["ok"] or not second["ok"]:
        return _result([], [_issue("error", "input_error", "input", "Both inputs must be readable JSON objects.")])
    if graph_path != "":
        var graph := _read(graph_path)
        if not graph["ok"]:
            return _result([], [_issue("error", "input_error", graph_path, "Dependency graph must be a readable JSON object.")])
        if not graph["data"].has("edges"):
            return _result([], [_issue("error", "invalid_graph", graph_path, "Dependency graph requires an edges array.")])
        return analyze(first["data"], second["data"], graph["data"])
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
