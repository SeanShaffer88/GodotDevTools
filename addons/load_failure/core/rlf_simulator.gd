## Resource Load Failure Simulator - what if this load fails?
## For each runtime load (load(), ResourceLoader.load(), load_threaded_get())
## it asks what happens when the result is null: a result chained straight
## into a call crashes; a result stored in a variable that is used before
## any null check crashes; a threaded load fetched without checking
## load_threaded_get_status may block or return null. Literal res:// paths
## that do not exist are reported. preload() is compile-time and skipped.
extends RefCounted

const EXTS: Array[String] = ["gd"]
const DEFAULTS := {}

var _assign_re := RegEx.create_from_string("^\\s*var\\s+([A-Za-z_][A-Za-z0-9_]*)[^=]*=\\s*(?:ResourceLoader\\.)?(load|load_threaded_get)\\(")
var _chain_re := RegEx.create_from_string("(?<!pre)(?<![A-Za-z_.])load\\([^()]*\\)\\.[A-Za-z_]+\\(")
var _literal_re := RegEx.create_from_string("(?<!pre)(?<![A-Za-z_])load\\(\\s*\"(res://[^\"%]+)\"\\s*\\)")


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var loads := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := str(texts[path]).split("\n")
        var threaded_status := str(texts[path]).contains("load_threaded_get_status")
        for index in range(lines.size()):
            var code := lines[index].get_slice("#", 0) if not lines[index].contains("\"#") else lines[index]
            for m in _literal_re.search_all(code):
                loads += 1
                if not ResourceLoader.exists(m.get_string(1)) and not FileAccess.file_exists(m.get_string(1)):
                    issues.append(_issue("error", "missing_resource", str(path), index + 1, "load(\"%s\"): the file does not exist." % m.get_string(1), "Fix the path or add the resource."))
            if _chain_re.search(code) != null:
                issues.append(_issue("warning", "chained_load", str(path), index + 1, "A load() result is used directly; if the file is missing this line errors.", "Store the result, check it for null, and handle the failure."))
            if code.contains("load_threaded_get(") and not threaded_status:
                issues.append(_issue("warning", "threaded_no_status", str(path), index + 1, "load_threaded_get() without load_threaded_get_status() in this script: it blocks until loaded and returns null on failure.", "Poll load_threaded_get_status() until THREAD_LOAD_LOADED, and handle THREAD_LOAD_FAILED."))
            var am := _assign_re.search(code)
            if am == null:
                continue
            var name := am.get_string(1)
            var base := _indent(lines[index])
            for j in range(index + 1, lines.size()):
                var s := lines[j].strip_edges()
                if s == "" or s.begins_with("#"):
                    continue
                if _indent(lines[j]) < base:
                    break
                if RegEx.create_from_string("(if|elif|while|assert)\\b.*\\b%s\\b|is_instance_valid\\(\\s*%s|\\b%s\\s*(==|!=)\\s*null" % [name, name, name]).search(s) != null:
                    break
                if RegEx.create_from_string("\\b%s\\s*\\.\\s*[A-Za-z_]" % name).search(s) != null:
                    issues.append(_issue("warning", "unchecked_load", str(path), j + 1, "`%s` (loaded on line %d) is used before any null check." % [name, index + 1], "Check `if %s == null:` and handle the missing resource (fallback, error message) before using it." % name))
                    break
    return _finish({"scripts": texts.size(), "literal_loads": loads}, issues)


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
    var lines: Array = ["# Resource Load Failure Simulator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
