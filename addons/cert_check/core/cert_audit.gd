## Compare a user-defined checklist with recorded review results; no certification claim.
extends RefCounted

func analyze(profile: Dictionary, results: Dictionary) -> Dictionary:
    var issues: Array = []
    var rows: Array = []
    if typeof(profile.get("requirements")) != TYPE_ARRAY or typeof(results.get("checks")) != TYPE_DICTIONARY:
        return _result(rows, [_issue("error", "input_error", "input", "Expected requirements array and checks object.")])
    if profile["requirements"].is_empty():
        return _result(rows, [_issue("error", "input_error", "requirements", "Checklist must contain at least one requirement.")])
    var checks: Dictionary = results["checks"]
    var seen := {}
    for req in profile["requirements"]:
        if typeof(req) != TYPE_DICTIONARY or typeof(req.get("id")) != TYPE_STRING or str(req.get("id", "")).is_empty() or (req.has("evidence_required") and typeof(req["evidence_required"]) != TYPE_BOOL):
            issues.append(_issue("error", "invalid_requirement", "requirements", "Every requirement needs a nonempty id and a boolean evidence_required if present."))
            continue
        var id := str(req["id"])
        if seen.has(id):
            issues.append(_issue("error", "duplicate_requirement", id, "Requirement id occurs more than once."))
            continue
        seen[id] = true
        if not checks.has(id):
            issues.append(_issue("warning", "missing_check", id, "No review result is recorded."))
            rows.append({"id": id, "status": "missing"})
            continue
        var review = checks[id]
        if typeof(review) != TYPE_DICTIONARY or str(review.get("status", "")) not in ["pass", "fail", "skip"] or (review.has("evidence") and typeof(review["evidence"]) != TYPE_STRING):
            issues.append(_issue("error", "invalid_check", id, "Expected pass, fail or skip status and optional string evidence."))
            continue
        var status := str(review["status"])
        rows.append({"id": id, "status": status})
        if status == "fail":
            issues.append(_issue("warning", "failed_check", id, "Requirement was marked failed."))
        elif status == "skip":
            issues.append(_issue("warning", "skipped_check", id, "Requirement was skipped."))
        elif bool(req.get("evidence_required", false)) and str(review.get("evidence", "")).strip_edges().is_empty():
            issues.append(_issue("warning", "missing_evidence", id, "Passing result requires evidence."))
    for id in checks:
        if not seen.has(id):
            issues.append(_issue("warning", "unknown_check", str(id), "Review result has no matching requirement."))
    return _result(rows, issues)

func _issue(severity: String, kind: String, path: String, message: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": "Review the profile and recorded results."}

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
    var lines: Array[String] = ["# Platform Certification Checklist Runner", "", "Summary: " + str(result["summary"]), "", "## Results"]
    for row in result["rows"]:
        lines.append("- " + str(row))
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s" % [issue["kind"], issue["path"], issue["message"]])
    return "\n".join(lines) + "\n"
