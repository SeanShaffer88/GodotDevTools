## SARIF Exporter - reports to SARIF 2.1.0.
## One SARIF run per tool: the driver is the tool folder name, rules are the
## finding kinds, and each finding becomes a result with level error /
## warning / note, the message plus its fix, and a location when the path is
## a res:// file (uri relative to the project root, startLine when known).
## The CLI writes gdt.sarif next to its report.
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

const DEFAULTS := {}
const SELF := "sarif_export"
const LEVELS := {"error": "error", "warning": "warning", "info": "note"}


func evaluate(reports: Dictionary, skipped: Array = [], options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    for p in skipped:
        issues.append(_issue("info", "skipped_report", p, 0, "Not a valid report; left out of the SARIF log.", "Validate it with the Report Schema tool."))
    var runs: Array = []
    var results_total := 0
    var tools: Array = reports.keys()
    tools.sort()
    for tool in tools:
        var rules := {}
        var results: Array = []
        for i in reports[tool]["issues"]:
            if not _valid_issue(i):
                continue
            var kind := str(i["kind"])
            if not rules.has(kind):
                rules[kind] = {"id": kind, "name": kind, "shortDescription": {"text": kind.replace("_", " ")}}
            var text := str(i["message"])
            if str(i.get("fix", "")) != "":
                text += " Fix: " + str(i["fix"])
            var r := {"ruleId": kind, "level": LEVELS[str(i["severity"])], "message": {"text": text}}
            var path := str(i.get("path", ""))
            if path.begins_with("res://") and path.length() > 6:
                var loc := {"physicalLocation": {"artifactLocation": {"uri": path.trim_prefix("res://"), "uriBaseId": "PROJECTROOT"}}}
                if int(i.get("line", 0)) > 0:
                    loc["physicalLocation"]["region"] = {"startLine": int(i["line"])}
                r["locations"] = [loc]
            results.append(r)
        results_total += results.size()
        runs.append({"tool": {"driver": {"name": "GodotDevTools/" + tool, "informationUri": "https://github.com/SeanShaffer88/GodotDevTools", "rules": rules.values()}},
            "originalUriBaseIds": {"PROJECTROOT": {"uri": "file:///"}}, "results": results})
    var sarif := {"$schema": "https://json.schemastore.org/sarif-2.1.0.json", "version": "2.1.0", "runs": runs}
    return _finish({"runs": runs.size(), "results": results_total}, issues, {"artifacts": {"gdt.sarif": JSON.stringify(sarif, "  ")}})


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
    var lines: Array = ["# SARIF Exporter", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
