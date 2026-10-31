## Finding Suppression Baseline - accepted findings.
## Each suppression names a tool, kind and path (and optionally text the
## message must contain), carries a written justification and may expire.
## Matching findings are suppressed; every other finding is re-emitted as
## unsuppressed_finding with its original severity so one --fail-on gates
## the whole suite. Suppressions without justification are refused; expired
## ones stop suppressing; ones that match nothing are reported for cleanup.
## Reports themselves are never modified.
extends RefCounted

const EXTS: Array[String] = ["json"]
## Reports folder -> {"reports": {tool: report}, "skipped": [path]}. A report is
## <dir>/<tool>/<tool>.json holding a dictionary with an "issues" array.
func load_reports(dir_path: String, skip: Array = []) -> Dictionary:
    var out := {"reports": {}, "skipped": []}
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return out
    var names: Array = Array(dir.get_directories())
    names.sort()
    for tool in names:
        if tool in skip or tool.begins_with("."):
            continue
        var p := dir_path.path_join(tool).path_join(tool + ".json")
        if not FileAccess.file_exists(p):
            continue
        var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
        if typeof(data) == TYPE_DICTIONARY and typeof(data.get("issues")) == TYPE_ARRAY and data["issues"].all(func(i): return _valid_issue(i)):
            out["reports"][tool] = data
        else:
            out["skipped"].append(p)
    return out


func _valid_issue(i: Variant) -> bool:
    return typeof(i) == TYPE_DICTIONARY and str(i.get("severity", "")) in ["error", "warning", "info"] and i.has("kind") and i.has("message")

const DEFAULTS := {"suppressions": "res://gdt_suppressions.json", "today": ""}
const SELF := "suppressions"


func run(input: String = "res://reports", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if DirAccess.open(input) == null:
        return _fail(input, "Reports folder not found.", "Run tool CLIs first, then pass --reports=<folder>.", "bad_input")
    var list: Variant = _read_json(str(opts["suppressions"]))
    if typeof(list) != TYPE_ARRAY:
        return _fail(str(opts["suppressions"]), "Suppression list missing or not a JSON array.", "See the README for the format.", "bad_suppressions")
    return evaluate(load_reports(input, [SELF])["reports"], list, opts)


func evaluate(reports: Dictionary, list: Array, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var today := str(opts["today"]) if str(opts["today"]) != "" else Time.get_date_string_from_system()
    var issues: Array = []
    var active: Array = []
    for n in range(list.size()):
        var s: Variant = list[n]
        if typeof(s) != TYPE_DICTIONARY or not s.has("tool") or not s.has("kind"):
            issues.append(_issue("error", "bad_suppressions", str(opts["suppressions"]), 0, "Entry %d needs tool and kind." % n, "Fix the entry."))
            continue
        var label := "%s/%s %s" % [s["tool"], s["kind"], s.get("path", "*")]
        if str(s.get("justification", "")).strip_edges() == "":
            issues.append(_issue("error", "missing_justification", str(opts["suppressions"]), 0, "Suppression %s has no justification and is ignored." % label, "Write why the finding is acceptable."))
            continue
        if str(s.get("expires", "")) != "" and str(s["expires"]) < today:
            issues.append(_issue("warning", "expired_suppression", str(opts["suppressions"]), 0, "Suppression %s expired on %s and no longer applies." % [label, s["expires"]], "Fix the finding, or renew the suppression with a new justification."))
            continue
        active.append({"s": s, "used": 0, "label": label})
    var suppressed := 0
    var tools: Array = reports.keys()
    tools.sort()
    for tool in tools:
        for i in reports[tool]["issues"]:
            var hit := false
            for a in active:
                var s: Dictionary = a["s"]
                if str(s["tool"]) == tool and str(s["kind"]) == str(i["kind"]) and (not s.has("path") or str(s["path"]) == str(i.get("path", ""))) and (not s.has("message_contains") or str(i["message"]).contains(str(s["message_contains"]))):
                    a["used"] += 1
                    hit = true
                    break
            if hit:
                suppressed += 1
            else:
                issues.append(_issue(str(i["severity"]), "unsuppressed_finding", str(i.get("path", "")), int(i.get("line", 0)), "[%s] %s: %s" % [tool, i["kind"], i["message"]], str(i.get("fix", ""))))
    for a in active:
        if a["used"] == 0:
            issues.append(_issue("info", "unused_suppression", str(opts["suppressions"]), 0, "Suppression %s matches nothing." % a["label"], "Remove it; the finding is gone."))
    return _finish({"reports": tools.size(), "suppressed": suppressed, "active_suppressions": active.size()}, issues)


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
    var lines: Array = ["# Finding Suppression Baseline", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
