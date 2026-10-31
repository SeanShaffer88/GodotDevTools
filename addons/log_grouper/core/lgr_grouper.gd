## Error Log Grouper - log signature grouping.
## Finds lines starting with ERROR:, SCRIPT ERROR:, USER ERROR:, WARNING: or
## USER WARNING: in captured Godot output, masks single-quoted names and
## numbers so repeats of the same problem share a signature, and counts each
## group with its first line and "at:" location.
extends RefCounted

const EXTS: Array[String] = ["log", "txt"]
var _quote_re := RegEx.create_from_string("'[^']*'")
var _num_re := RegEx.create_from_string("(?<![A-Za-z_])\\d+(?:\\.\\d+)?")
const PREFIXES: Array[String] = ["SCRIPT ERROR:", "USER SCRIPT ERROR:", "USER ERROR:", "ERROR:", "USER WARNING:", "WARNING:"]


## Group Godot log lines: [{signature, level, count, first_line, location}].
func groups(text: String) -> Array:
    var by_sig := {}
    var order: Array = []
    var lines := text.split("\n")
    for index in range(lines.size()):
        var s := lines[index].strip_edges()
        var prefix := ""
        for p in PREFIXES:
            if s.begins_with(p):
                prefix = p
                break
        if prefix == "":
            continue
        var sig := normalize(s)
        var level := "warning" if prefix.contains("WARNING") else "error"
        var location := ""
        if index + 1 < lines.size() and lines[index + 1].strip_edges().begins_with("at:"):
            location = lines[index + 1].strip_edges().trim_prefix("at:").strip_edges()
        if not by_sig.has(sig):
            by_sig[sig] = {"signature": sig, "level": level, "count": 0, "first_line": index + 1, "location": location}
            order.append(sig)
        by_sig[sig]["count"] += 1
    var out: Array = []
    for sig in order:
        out.append(by_sig[sig])
    out.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]) if a["count"] != b["count"] else int(a["first_line"]) < int(b["first_line"]))
    return out


## Replace single-quoted strings with '<str>' and numbers with N.
func normalize(line: String) -> String:
    var s := _quote_re.sub(line, "'<str>'", true)
    return _num_re.sub(s, "N", true)

func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    if not FileAccess.file_exists(input):
        return _fail(input, "Log file not found.", "Pass --log=<path to a captured Godot log>.", "bad_input")
    return evaluate(FileAccess.get_file_as_string(input), input, options)

const DEFAULTS := {}


func evaluate(text: String, path: String = "", options: Dictionary = {}) -> Dictionary:
    var gs := groups(text)
    var issues: Array = []
    var errors := 0
    var warnings := 0
    for g in gs:
        if g["level"] == "error":
            errors += int(g["count"])
        else:
            warnings += int(g["count"])
        issues.append(_issue("warning" if g["level"] == "error" else "info", "%s_group" % g["level"], path, g["first_line"],
            "x%d %s%s" % [g["count"], g["signature"], (" (at %s)" % g["location"]) if g["location"] != "" else ""],
            "Fix the first occurrence; repeats usually share one cause."))
    return _finish({"groups": gs.size(), "errors": errors, "warnings": warnings}, issues, {"groups": gs})


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
    var lines: Array = ["# Error Log Grouper", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
