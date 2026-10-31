## JUnit Exporter - reports to JUnit XML.
## Each tool becomes a <testsuite>; each finding kind a <testcase> that fails
## when it has findings at or above the fail level (listing every finding in
## the failure body). A tool with no failing findings gets one passing
## "clean" case so it still appears in test views.
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

func run(input: String = "res://reports", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Reports folder not found.", "Run some tool CLIs first, then pass --reports=<folder>.", "bad_input")
    var loaded := load_reports(input, [SELF])
    return evaluate(loaded["reports"], loaded["skipped"], _opts(options))

const DEFAULTS := {"fail_level": "warning"}
const SELF := "junit_export"
const RANK := {"info": 0, "warning": 1, "error": 2}


func _x(s: String) -> String:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


func evaluate(reports: Dictionary, skipped: Array = [], options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var min_rank := int(RANK.get(str(opts["fail_level"]), 1))
    var issues: Array = []
    for p in skipped:
        issues.append(_issue("info", "skipped_report", p, 0, "Not a valid report; left out of the JUnit file.", "Validate it with the Report Schema tool."))
    var xml: Array = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<testsuites name=\"GodotDevTools\">"]
    var total_cases := 0
    var total_fail := 0
    var tools: Array = reports.keys()
    tools.sort()
    for tool in tools:
        var by_kind := {}
        for i in reports[tool]["issues"]:
            if _valid_issue(i) and int(RANK[str(i["severity"])]) >= min_rank:
                if not by_kind.has(i["kind"]):
                    by_kind[i["kind"]] = []
                by_kind[i["kind"]].append(i)
        var cases: Array = []
        var kinds: Array = by_kind.keys()
        kinds.sort()
        for k in kinds:
            var body: Array = []
            for i in by_kind[k]:
                body.append("%s:%s %s Fix: %s" % [i.get("path", ""), i.get("line", 0), i["message"], i.get("fix", "")])
            cases.append("    <testcase classname=\"%s\" name=\"%s\"><failure message=\"%d finding(s)\" type=\"%s\">%s</failure></testcase>" % [_x(tool), _x(str(k)), by_kind[k].size(), _x(str(k)), _x("\n".join(body))])
        if cases.is_empty():
            cases.append("    <testcase classname=\"%s\" name=\"clean\"/>" % _x(tool))
        xml.append("  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\">" % [_x(tool), cases.size(), kinds.size()])
        xml.append_array(cases)
        xml.append("  </testsuite>")
        total_cases += cases.size()
        total_fail += kinds.size()
    xml.append("</testsuites>")
    return _finish({"suites": tools.size(), "cases": total_cases, "failures": total_fail}, issues, {"artifacts": {"gdt-junit.xml": "\n".join(xml) + "\n"}})


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
    var lines: Array = ["# JUnit Exporter", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
