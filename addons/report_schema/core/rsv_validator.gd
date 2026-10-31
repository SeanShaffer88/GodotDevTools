## Report Schema - shared report contract.
## Every tool writes <tool>.json with a "summary" object and an "issues"
## array whose items carry severity (error | warning | info), kind and
## message, and usually path, line and fix. SCHEMA is the JSON Schema
## (draft 2020-12) for that contract; the CLI writes it next to its report as
## report.schema.json. The validator checks the required parts directly.
## Consumers (exporters, dashboards, diffs) rely only on this contract.
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

const DEFAULTS := {}
const SELF := "report_schema"
const SCHEMA := {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "GodotDevTools tool report",
    "type": "object",
    "required": ["summary", "issues"],
    "properties": {
        "summary": {"type": "object"},
        "issues": {"type": "array", "items": {
            "type": "object",
            "required": ["severity", "kind", "message"],
            "properties": {
                "severity": {"enum": ["error", "warning", "info"]},
                "kind": {"type": "string", "description": "Stable finding identifier; --fail-on uses it."},
                "message": {"type": "string"},
                "path": {"type": "string", "description": "res:// path or other location label."},
                "line": {"type": "integer", "minimum": 0, "description": "1-based line; 0 or absent when not applicable."},
                "fix": {"type": "string", "description": "Plain-words suggested fix."}}}}}}


func run(input: String = "res://reports", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Reports folder not found.", "Run some tool CLIs first, then pass --reports=<folder>.", "bad_input")
    var dir := DirAccess.open(input)
    var docs := {}
    for tool in dir.get_directories():
        if tool == SELF:
            continue
        var p := input.path_join(tool).path_join(tool + ".json")
        if FileAccess.file_exists(p):
            docs[p] = JSON.parse_string(FileAccess.get_file_as_string(p))
    return evaluate(docs)


## docs: {path: parsed JSON or null}
func evaluate(docs: Dictionary) -> Dictionary:
    var issues: Array = []
    var valid := 0
    var paths: Array = docs.keys()
    paths.sort()
    for p in paths:
        var d: Variant = docs[p]
        if typeof(d) != TYPE_DICTIONARY or not d.has("summary") or not d.has("issues"):
            issues.append(_issue("info", "not_a_report", p, 0, "Not a findings report (no summary and issues).", "Ignore if this tool writes results, not findings."))
            continue
        var problems: Array = []
        if typeof(d["summary"]) != TYPE_DICTIONARY:
            problems.append("summary is not an object")
        if typeof(d.get("issues")) != TYPE_ARRAY:
            problems.append("issues is not an array")
        else:
            for n in range(d["issues"].size()):
                var i: Variant = d["issues"][n]
                if not _valid_issue(i):
                    problems.append("issues[%d] needs severity (error|warning|info), kind and message" % n)
                elif i.has("line") and (typeof(i["line"]) not in [TYPE_INT, TYPE_FLOAT] or float(i["line"]) < 0):
                    problems.append("issues[%d].line must be a non-negative integer" % n)
        if problems.is_empty():
            valid += 1
        else:
            issues.append(_issue("error", "schema_violation", p, 0, "; ".join(problems.slice(0, 5)), "Fix the tool's report writer to follow the report schema."))
    return _finish({"reports": paths.size(), "valid": valid}, issues, {"artifacts": {"report.schema.json": JSON.stringify(SCHEMA, "  ")}})


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
    var lines: Array = ["# Report Schema", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
