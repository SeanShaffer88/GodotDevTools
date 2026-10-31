## Content Descriptor Checklist - questionnaire bookkeeping.
## Questions (your own wording, with allowed options) and recorded answers
## (value, evidence path, reviewer, date) live in one JSON file. The tool
## checks completeness, allowed values, that evidence files exist where a
## question requires evidence, and that answers are not older than the
## allowed age. It never decides a rating; rating bodies do.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"max_age_days": 365, "today": ""}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var data: Variant = _read_json(input)
    if typeof(data) != TYPE_DICTIONARY or typeof(data.get("questions")) != TYPE_ARRAY:
        return _fail(input, "Questionnaire missing or without a questions array.", "See the README for the format.", "bad_input")
    var result := evaluate(data, options)
    for i in result["issues"]:
        if i["path"] == "":
            i["path"] = input
    return result


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var today := str(opts["today"])
    if today == "":
        today = Time.get_date_string_from_system()
    var now := Time.get_unix_time_from_datetime_string(today)
    var answers: Dictionary = data.get("answers", {}) if typeof(data.get("answers", {})) == TYPE_DICTIONARY else {}
    var issues: Array = []
    var answered := 0
    for q in data["questions"]:
        var id := str(q.get("id", ""))
        if not answers.has(id):
            issues.append(_issue("warning", "unanswered", "", 0, "%s (%s) has no recorded answer." % [id, q.get("text", "")], "Answer it with the evidence you reviewed."))
            continue
        answered += 1
        var a: Dictionary = answers[id]
        var options_list: Array = q.get("options", [])
        if not options_list.is_empty() and str(a.get("value", "")) not in options_list:
            issues.append(_issue("error", "invalid_answer", "", 0, "%s answer '%s' is not one of %s." % [id, a.get("value", ""), ", ".join(options_list)], "Pick one of the allowed options."))
        if q.get("evidence_required", false):
            var ev := str(a.get("evidence", ""))
            if ev == "" or not (FileAccess.file_exists(ev) or DirAccess.open(ev) != null):
                issues.append(_issue("warning", "missing_evidence", "", 0, "%s requires evidence; %s." % [id, "none recorded" if ev == "" else ev + " does not exist"], "Record the scene, screenshot or document the answer is based on."))
        var when := str(a.get("date", ""))
        if when != "":
            var t := Time.get_unix_time_from_datetime_string(when)
            var age := int((now - t) / 86400)
            if age > int(opts["max_age_days"]):
                issues.append(_issue("warning", "stale_answer", "", 0, "%s was last reviewed %s (%d days ago)." % [id, when, age], "Review it again; content changes between releases."))
    return _finish({"questions": data["questions"].size(), "answered": answered}, issues)


func _walk(path: String, out: Array) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not name.begins_with(".") and name not in ["addons", "reports", "visual_reports"]:
            var child := path.path_join(name)
            if dir.current_is_dir():
                _walk(child, out)
            elif name.get_extension().to_lower() in EXTS:
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()


func _opts(options: Dictionary) -> Dictionary:
    var merged: Dictionary = DEFAULTS.duplicate(true)
    merged.merge(options, true)
    return merged


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))


func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}


func _fail(path: String, message: String, fix: String, kind: String = "scan_error") -> Dictionary:
    return {"summary": {"issues": 1}, "issues": [_issue("error", kind, path, 0, message, fix)]}


func _finish(summary: Dictionary, issues: Array, extra: Dictionary = {}) -> Dictionary:
    issues.sort_custom(func(a, b): return "%s|%08d|%s" % [a["path"], int(a["line"]), a["kind"]] < "%s|%08d|%s" % [b["path"], int(b["line"]), b["kind"]])
    summary["issues"] = issues.size()
    var result := {"summary": summary, "issues": issues}
    result.merge(extra)
    return result


func _count(result: Dictionary, kind: String) -> int:
    var n := 0
    for issue in result["issues"]:
        if issue["kind"] == kind:
            n += 1
    return n


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array = ["# Content Descriptor Checklist", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
