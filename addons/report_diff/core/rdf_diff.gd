## Report Diff - new and fixed findings.
## Loads both report folders and keys each finding by tool, kind, path and
## message (numbers in the message masked), so a finding whose line moved is
## still the same finding. Reports new findings (gate on these in pull
## requests) and fixed ones. Duplicate keys are counted, so a second copy of
## the same finding is new.
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

const DEFAULTS := {"after": ""}
const SELF := "report_diff"

var _num_re := RegEx.create_from_string("\\d+")


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    for d in [input, str(opts["after"])]:
        if DirAccess.open(d) == null:
            return _fail(d, "Reports folder not found.", "Pass --before and --after report folders.", "bad_input")
    return evaluate(load_reports(input, [SELF])["reports"], load_reports(str(opts["after"]), [SELF])["reports"])


func key(tool: String, i: Dictionary) -> String:
    return "%s|%s|%s|%s" % [tool, i["kind"], i.get("path", ""), _num_re.sub(str(i["message"]), "N", true)]


func _bag(reports: Dictionary) -> Dictionary:
    var bag := {}
    for tool in reports.keys():
        for i in reports[tool]["issues"]:
            if not _valid_issue(i):
                continue
            var k := key(tool, i)
            if not bag.has(k):
                bag[k] = []
            var copy: Dictionary = i.duplicate()
            copy["tool"] = tool
            bag[k].append(copy)
    return bag


func evaluate(before: Dictionary, after: Dictionary) -> Dictionary:
    var a := _bag(before)
    var b := _bag(after)
    var issues: Array = []
    var unchanged := 0
    var keys: Array = b.keys()
    keys.sort()
    for k in keys:
        var had: int = a.get(k, []).size()
        for n in range(b[k].size()):
            var i: Dictionary = b[k][n]
            if n < had:
                unchanged += 1
            else:
                issues.append(_issue("warning", "new_finding", str(i.get("path", "")), int(i.get("line", 0)), "[%s] %s: %s" % [i["tool"], i["kind"], i["message"]], str(i.get("fix", "Fix it before merging."))))
    var old_keys: Array = a.keys()
    old_keys.sort()
    for k in old_keys:
        var now: int = b.get(k, []).size()
        for n in range(now, a[k].size()):
            var j: Dictionary = a[k][n]
            issues.append(_issue("info", "fixed_finding", str(j.get("path", "")), int(j.get("line", 0)), "[%s] %s: %s" % [j["tool"], j["kind"], j["message"]], "Nothing to do."))
    return _finish({"new": issues.filter(func(x): return x["kind"] == "new_finding").size(), "fixed": issues.filter(func(x): return x["kind"] == "fixed_finding").size(), "unchanged": unchanged}, issues)


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
    var lines: Array = ["# Report Diff", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
