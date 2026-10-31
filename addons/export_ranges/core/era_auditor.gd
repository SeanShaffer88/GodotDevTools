## Export Variable Range Auditor - static range checks.
## Reads @export_range(min, max, ...) declarations from GDScript and checks
## the script default and every value a scene stores for that property on a
## node using the script. or_greater / or_less lift the matching limit,
## as they do in the inspector. Read-only.
extends RefCounted

const EXTS: Array[String] = ["gd", "tscn"]
const DEFAULTS := {"report_unhinted": false}

var _range_re := RegEx.create_from_string("@export_range\\(([^)]*)\\)\\s*var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*[A-Za-z_]+)?\\s*:?=?\\s*([-+0-9.eE]+)?")
var _plain_re := RegEx.create_from_string("^\\s*@export\\s+var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*(int|float)\\b")


## Script text -> {name: {min, max, open_min, open_max, line, default?}} plus "_unhinted": [{name, line}].
func ranges(text: String) -> Dictionary:
    var out := {}
    var unhinted: Array = []
    var lines := text.split("\n")
    for index in range(lines.size()):
        var m := _range_re.search(lines[index])
        if m != null:
            var args := m.get_string(1).split(",")
            if args.size() < 2 or not args[0].strip_edges().is_valid_float() or not args[1].strip_edges().is_valid_float():
                continue
            var entry := {"min": float(args[0]), "max": float(args[1]), "open_min": false, "open_max": false, "line": index + 1}
            for a in args:
                var flag := a.strip_edges().trim_prefix("\"").trim_suffix("\"")
                if flag == "or_greater":
                    entry["open_max"] = true
                elif flag == "or_less":
                    entry["open_min"] = true
            if m.get_string(3) != "" and m.get_string(3).is_valid_float():
                entry["default"] = float(m.get_string(3))
            out[m.get_string(2)] = entry
            continue
        var p := _plain_re.search(lines[index])
        if p != null:
            unhinted.append({"name": p.get_string(1), "line": index + 1})
    out["_unhinted"] = unhinted
    return out


func _outside(value: float, r: Dictionary) -> bool:
    return (value < float(r["min"]) and not r["open_min"]) or (value > float(r["max"]) and not r["open_max"])


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var scripts := {}
    var checked := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
        elif str(path).get_extension() == "gd":
            scripts[path] = ranges(str(texts[path]))
            for name in scripts[path].keys():
                if name == "_unhinted":
                    continue
                var r: Dictionary = scripts[path][name]
                if r.has("default"):
                    checked += 1
                    if _outside(float(r["default"]), r):
                        issues.append(_issue("warning", "default_out_of_range", str(path), r["line"], "Default %s = %s is outside %s..%s." % [name, r["default"], r["min"], r["max"]], "Change the default or widen the range."))
            if opts["report_unhinted"]:
                for u in scripts[path]["_unhinted"]:
                    issues.append(_issue("info", "no_range_hint", str(path), u["line"], "Numeric export `%s` has no range hint." % u["name"], "Use @export_range so designers cannot enter impossible values."))
    for path in texts.keys():
        if texts[path] == null or str(path).get_extension() != "tscn":
            continue
        var ext := {}
        var current_script := ""
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            if s.begins_with("[ext_resource"):
                ext[_attr(s, "id")] = _attr(s, "path")
            elif s.begins_with("["):
                current_script = ""
                # a node's script line follows its header; reset per section
            elif s.begins_with("script = ExtResource(\""):
                current_script = str(ext.get(s.trim_prefix("script = ExtResource(\"").get_slice("\"", 0), ""))
            elif current_script != "" and scripts.has(current_script) and s.contains(" = "):
                var key := s.get_slice(" = ", 0)
                var value := s.substr(key.length() + 3)
                if scripts[current_script].has(key) and key != "_unhinted" and value.is_valid_float():
                    checked += 1
                    var r: Dictionary = scripts[current_script][key]
                    if _outside(float(value), r):
                        issues.append(_issue("warning", "out_of_range", str(path), index + 1, "%s = %s is outside %s..%s declared in %s:%d." % [key, value, r["min"], r["max"], current_script, r["line"]], "Fix the value in the inspector, or widen the range if the value is intended."))
    return _finish({"scripts": scripts.size(), "values_checked": checked}, issues)


func _attr(line: String, key: String) -> String:
    var marker := " " + key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var start := i + marker.length()
    return line.substr(start, line.find("\"", start) - start)

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
    var lines: Array = ["# Export Variable Range Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
