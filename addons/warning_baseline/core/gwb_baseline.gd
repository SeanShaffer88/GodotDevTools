## GDScript Warning Baseline - warning ratchet.
## Godot does not print GDScript warnings in headless runs, so this tool
## detects three common warning patterns itself, named after Godot's codes:
## UNUSED_VARIABLE (a local var never mentioned again in its function),
## UNUSED_PARAMETER (a parameter not mentioned in the body and not prefixed
## with _), and UNREACHABLE_CODE (a statement after return/break/continue in
## the same block). Counts per file may only go down against the baseline.
## The report's suggested_baseline is this run's counts.
extends RefCounted

const EXTS: Array[String] = ["gd"]
const DEFAULTS := {"baseline": ""}
const CODES: Array[String] = ["UNUSED_VARIABLE", "UNUSED_PARAMETER", "UNREACHABLE_CODE"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var base := {}
    if str(opts["baseline"]) != "":
        var b: Variant = _read_json(str(opts["baseline"]))
        if typeof(b) != TYPE_DICTIONARY:
            return _fail(str(opts["baseline"]), "Baseline missing or not a JSON object.", "Commit this report's suggested_baseline as the baseline.", "bad_input")
        base = b
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    return analyze(texts, {"baseline_data": base, "has_baseline": str(opts["baseline"]) != ""})


## [{code, line, detail}] for one script.
func warnings(text: String) -> Array:
    var out: Array = []
    var lines := text.split("\n")
    var i := 0
    var func_re := RegEx.create_from_string("^(\\s*)(?:static\\s+)?func\\s+[A-Za-z_][A-Za-z0-9_]*\\s*\\(([^)]*)\\)")
    var var_re := RegEx.create_from_string("^\\s*var\\s+([A-Za-z_][A-Za-z0-9_]*)")
    while i < lines.size():
        var fm := func_re.search(lines[i])
        if fm == null:
            i += 1
            continue
        var base := _indent(lines[i])
        var start := i
        var body: Array = []
        var j := i + 1
        while j < lines.size():
            var s := lines[j].strip_edges()
            if s != "" and not s.begins_with("#") and _indent(lines[j]) <= base:
                break
            body.append([j, lines[j]])
            j += 1
        var body_text := "\n".join(body.map(func(b): return _code(b[1])))
        for param in fm.get_string(2).split(",", false):
            var name := param.strip_edges().get_slice(":", 0).get_slice("=", 0).strip_edges()
            if name != "" and not name.begins_with("_") and not _mentions(body_text, name):
                out.append({"code": "UNUSED_PARAMETER", "line": start + 1, "detail": name})
        for k in range(body.size()):
            var vm := var_re.search(body[k][1])
            if vm != null:
                var vname := vm.get_string(1)
                if vname.begins_with("_"):
                    continue
                var rest := "\n".join(body.slice(k + 1).map(func(b): return _code(b[1])))
                var own := _code(body[k][1]).get_slice("=", 1)
                if not _mentions(rest, vname) and not _mentions(own, vname):
                    out.append({"code": "UNUSED_VARIABLE", "line": body[k][0] + 1, "detail": vname})
        for k in range(body.size()):
            var s2 := _code(body[k][1]).strip_edges()
            if s2 in ["return", "break", "continue"] or s2.begins_with("return "):
                var ind := _indent(body[k][1])
                for m in range(k + 1, body.size()):
                    var t := _code(body[m][1]).strip_edges()
                    if t == "":
                        continue
                    var ti := _indent(body[m][1])
                    if ti == ind and not t.begins_with("elif") and not t.begins_with("else"):
                        out.append({"code": "UNREACHABLE_CODE", "line": body[m][0] + 1, "detail": t.substr(0, 40)})
                    break
        i = j
    return out


func _mentions(text: String, name: String) -> bool:
    return RegEx.create_from_string("(?<![A-Za-z0-9_])" + name + "(?![A-Za-z0-9_])").search(text) != null


func _code(line: String) -> String:
    return line.get_slice("#", 0) if not line.contains("\"") else line


func _indent(line: String) -> int:
    var n := 0
    for c in line:
        if c == "\t":
            n += 4
        elif c == " ":
            n += 1
        else:
            break
    return n


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var base: Dictionary = options.get("baseline_data", {})
    var has_base: bool = options.get("has_baseline", not base.is_empty())
    var issues: Array = []
    var counts := {}
    var total := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var ws := warnings(str(texts[path]))
        if ws.is_empty():
            continue
        var c := {}
        for w in ws:
            c[w["code"]] = int(c.get(w["code"], 0)) + 1
        counts[path] = c
        total += ws.size()
        if not has_base:
            continue
        var known: Dictionary = base.get(path, {}) if typeof(base.get(path, {})) == TYPE_DICTIONARY else {}
        if known.is_empty():
            issues.append(_issue("warning", "new_warning_file", str(path), ws[0]["line"], "%d warning patterns in a file the baseline has none for (first: %s %s)." % [ws.size(), ws[0]["code"], ws[0]["detail"]], "Fix them; new files start clean."))
            continue
        for code in c.keys():
            if int(c[code]) > int(known.get(code, 0)):
                var first: Dictionary = ws.filter(func(w): return w["code"] == code)[0]
                issues.append(_issue("warning", "warning_increase", str(path), first["line"], "%s: %d, baseline %d (e.g. %s)." % [code, c[code], known.get(code, 0), first["detail"]], "Fix the new occurrences; the baseline may only go down."))
    return _finish({"files_with_warnings": counts.size(), "warnings": total}, issues, {"suggested_baseline": counts})


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
    var lines: Array = ["# GDScript Warning Baseline", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
