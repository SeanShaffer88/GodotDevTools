## Script Complexity Reporter - per-function metrics.
## Splits GDScript into functions by indentation and reports, for each one,
## a branch complexity (1 + if/elif/for/while/match arms/and/or/ternaries),
## its length in code lines, and its deepest block nesting. Read-only.
extends RefCounted

const EXTS: Array[String] = ["gd"]
const DEFAULTS := {"max_complexity": 12, "max_lines": 60, "max_nesting": 4}

var _func_re := RegEx.create_from_string("^(\\s*)(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
var _branch_re := RegEx.create_from_string("^(if|elif|for|while)\\b|\\band\\b|\\bor\\b|&&|\\|\\||\\bif\\b.*\\belse\\b")


func functions(text: String) -> Array:
    var out: Array = []
    var lines := text.split("\n")
    var i := 0
    while i < lines.size():
        var fm := _func_re.search(lines[i])
        if fm == null:
            i += 1
            continue
        var base := _indent(lines[i])
        var start := i
        var body_lines := 0
        var complexity := 1
        var max_depth := 0
        var body_indent := -1
        var in_match := -1
        var j := i + 1
        while j < lines.size():
            var raw: String = lines[j]
            var s := raw.strip_edges()
            if s == "" or s.begins_with("#"):
                j += 1
                continue
            var ind := _indent(raw)
            if ind <= base:
                break
            if body_indent < 0:
                body_indent = ind
            body_lines += 1
            var code := s.get_slice("#", 0) if not s.contains("\"") else s
            complexity += _branch_re.search_all(code).size()
            if in_match >= 0 and ind > in_match and s.ends_with(":") and not code.begins_with("if ") and not code.begins_with("for ") and not code.begins_with("while ") and not code.begins_with("elif ") and not code.begins_with("else"):
                complexity += 1
            if in_match >= 0 and ind <= in_match:
                in_match = -1
            if code.begins_with("match "):
                in_match = ind
            var depth := 0 if body_indent <= 0 else int((ind - body_indent) / max(1, _unit(lines, body_indent, base))) + 1
            max_depth = max(max_depth, depth - 1)
            j += 1
        out.append({"name": fm.get_string(2), "line": start + 1, "lines": body_lines, "complexity": complexity, "nesting": max_depth})
        i = j
    return out


func _unit(lines: Array, body_indent: int, base: int) -> int:
    return max(1, body_indent - base)


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
    var opts := _opts(options)
    var issues: Array = []
    var all: Array = []
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        for f in functions(str(texts[path])):
            f["path"] = str(path)
            all.append(f)
            if int(f["complexity"]) > int(opts["max_complexity"]):
                issues.append(_issue("warning", "complex_function", str(path), f["line"], "%s has branch complexity %d (limit %d)." % [f["name"], f["complexity"], opts["max_complexity"]], "Split decisions into helper functions or a lookup table; each branch needs a test."))
            if int(f["lines"]) > int(opts["max_lines"]):
                issues.append(_issue("info", "long_function", str(path), f["line"], "%s is %d code lines (limit %d)." % [f["name"], f["lines"], opts["max_lines"]], "Extract named steps into their own functions."))
            if int(f["nesting"]) > int(opts["max_nesting"]):
                issues.append(_issue("warning", "deep_nesting", str(path), f["line"], "%s nests %d levels deep (limit %d)." % [f["name"], f["nesting"], opts["max_nesting"]], "Return early, invert conditions, or extract the inner loop."))
    all.sort_custom(func(a, b): return int(a["complexity"]) > int(b["complexity"]))
    return _finish({"files": texts.size(), "functions": all.size(), "max_complexity": 0 if all.is_empty() else all[0]["complexity"]}, issues, {"functions": all})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Function | File | Complexity | Lines | Nesting |", "|---|---|---|---|---|"]
    for f in result.get("functions", []).slice(0, 25):
        out.append("| %s | `%s:%d` | %d | %d | %d |" % [f["name"], f["path"], f["line"], f["complexity"], f["lines"], f["nesting"]])
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
    var lines: Array = ["# Script Complexity Reporter", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
