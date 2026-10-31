## Typed GDScript Coverage Meter - static typing share.
## Counts typed and untyped declarations in GDScript: member and local
## variables/constants (typed with `: T` or inferred with `:=`), function
## parameters, and function return types. Reports per-file and project
## percentages and the untyped spots. Read-only.
extends RefCounted

const EXTS: Array[String] = ["gd"]
const DEFAULTS := {"min_percent": 0.0}

var _var_re := RegEx.create_from_string("^\\s*(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?(var|const)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(:=|:|=)?")
var _func_re := RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(([^)]*)\\)\\s*(->\\s*[A-Za-z_][A-Za-z0-9_\\[\\]\\.]*)?")


## Per-script counts: {typed, total, untyped: [{line, what}]}.
func measure(text: String) -> Dictionary:
    var typed := 0
    var total := 0
    var untyped: Array = []
    var lines := text.split("\n")
    for index in range(lines.size()):
        var line: String = lines[index]
        if line.strip_edges().begins_with("#"):
            continue
        var fm := _func_re.search(line)
        if fm != null:
            var name := fm.get_string(1)
            for param in fm.get_string(2).split(",", false):
                var p := param.strip_edges()
                if p == "":
                    continue
                total += 1
                if p.contains(":"):
                    typed += 1
                else:
                    untyped.append({"line": index + 1, "what": "parameter `%s` of %s" % [p.get_slice("=", 0).strip_edges(), name]})
            if name != "_init":
                total += 1
                if fm.get_string(3) != "":
                    typed += 1
                else:
                    untyped.append({"line": index + 1, "what": "return type of %s" % name})
            continue
        var vm := _var_re.search(line)
        if vm != null:
            total += 1
            var op := vm.get_string(3)
            if op == ":=" or op == ":" or (vm.get_string(1) == "const"):
                typed += 1
            else:
                untyped.append({"line": index + 1, "what": "%s `%s`" % [vm.get_string(1), vm.get_string(2)]})
    return {"typed": typed, "total": total, "untyped": untyped}


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var files: Array = []
    var typed := 0
    var total := 0
    var paths: Array = texts.keys()
    paths.sort()
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var m := measure(str(texts[path]))
        typed += int(m["typed"])
        total += int(m["total"])
        var pct: float = 100.0 if int(m["total"]) == 0 else 100.0 * m["typed"] / m["total"]
        files.append({"path": str(path), "typed": m["typed"], "total": m["total"], "percent": snappedf(pct, 0.1), "untyped": m["untyped"]})
        if pct < float(opts["min_percent"]):
            issues.append(_issue("warning", "below_threshold", str(path), 0,
                "%.1f%% typed (%d of %d), below %.1f%%." % [pct, m["typed"], m["total"], opts["min_percent"]],
                "Add types to the untyped spots listed in the report, starting with function signatures."))
    var project: float = 100.0 if total == 0 else 100.0 * typed / total
    if project < float(opts["min_percent"]):
        issues.append(_issue("warning", "project_below_threshold", "res://", 0,
            "Project is %.1f%% typed (%d of %d), below %.1f%%." % [project, typed, total, opts["min_percent"]],
            "Raise coverage file by file; ratchet the minimum up as it improves."))
    return _finish({"files": files.size(), "typed": typed, "total": total, "percent": snappedf(project, 0.1)}, issues, {"files": files})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| File | Typed | Total | % |", "|---|---|---|---|"]
    for f in result.get("files", []):
        out.append("| `%s` | %d | %d | %.1f |" % [f["path"], f["typed"], f["total"], f["percent"]])
    out.append("")
    return out

func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for path in paths:
        var file := FileAccess.open(path, FileAccess.READ)
        texts[path] = null if file == null else file.get_as_text()
    return analyze(texts, options)


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
    var lines: Array = ["# Typed GDScript Coverage Meter", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
