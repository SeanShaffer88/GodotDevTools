## Compare declared state transitions with observed transition records.
extends RefCounted

func analyze(model: Dictionary, trace: Dictionary) -> Dictionary:
    var issues: Array = []
    var rows: Array = []
    if typeof(model.get("transitions")) != TYPE_ARRAY or typeof(trace.get("transitions")) != TYPE_ARRAY:
        return _result(rows, [_issue("error", "input_error", "input", "Both inputs need transition arrays.")])
    if model["transitions"].is_empty():
        return _result(rows, [_issue("error", "input_error", "model", "Model must contain at least one transition.")])
    var declared := {}
    for index in range(model["transitions"].size()):
        var edge = model["transitions"][index]
        if not _valid(edge):
            issues.append(_issue("error", "invalid_transition", "model[%d]" % index, "Transition requires nonempty string from/to fields."))
            continue
        var key := JSON.stringify([edge["from"], edge["to"]])
        if declared.has(key):
            issues.append(_issue("error", "duplicate_transition", "model[%d]" % index, "Transition is declared twice."))
        else:
            declared[key] = {"from": edge["from"], "to": edge["to"], "count": 0}
    for index in range(trace["transitions"].size()):
        var edge = trace["transitions"][index]
        if not _valid(edge):
            issues.append(_issue("error", "invalid_transition", "trace[%d]" % index, "Transition requires nonempty string from/to fields."))
            continue
        var key := JSON.stringify([edge["from"], edge["to"]])
        if not declared.has(key):
            issues.append(_issue("warning", "unexpected_transition", "trace[%d]" % index, "Observed transition is not in the model."))
        else:
            declared[key]["count"] += 1
    var keys: Array = declared.keys()
    keys.sort()
    for key in keys:
        var row: Dictionary = declared[key]
        rows.append(row)
        if row["count"] == 0:
            issues.append(_issue("warning", "uncovered_transition", "%s -> %s" % [row["from"], row["to"]], "No matching transition was observed."))
    return _result(rows, issues)

func _valid(edge) -> bool:
    return typeof(edge) == TYPE_DICTIONARY and typeof(edge.get("from")) == TYPE_STRING and typeof(edge.get("to")) == TYPE_STRING and not str(edge.get("from", "")).is_empty() and not str(edge.get("to", "")).is_empty()

func _issue(severity: String, kind: String, path: String, message: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": "Review the model and recorded trace."}

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
    var lines: Array[String] = ["# State Transition Coverage Tracker", "", "Summary: " + str(result["summary"]), "", "## Results"]
    for row in result["rows"]:
        lines.append("- " + str(row))
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s" % [issue["kind"], issue["path"], issue["message"]])
    return "\n".join(lines) + "\n"
