## Resource UID Integrity Checker - static UID consistency.
## Collects the UID each file declares (text scene/resource headers,
## .import sidecars and Godot 4.4+ .uid sidecars), then checks every
## ext_resource uid and every literal uid:// string in scripts. A stale UID
## makes Godot fall back to the text path with a warning; a duplicate UID can
## load the wrong file. Read-only.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres", "import", "uid", "gd"]
const DEFAULTS := {}

var _uid_re := RegEx.create_from_string("uid://[a-z0-9]+")


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var declared := {}  # uid -> [paths]
    var by_path := {}   # resource path -> uid
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var p := str(path)
        var text := str(texts[path])
        var uid := ""
        var target := p
        var ext := p.get_extension()
        if ext in ["tscn", "tres"]:
            var head := text.get_slice("\n", 0)
            var i := head.find(" uid=\"")
            if i >= 0:
                uid = head.substr(i + 6).get_slice("\"", 0)
        elif ext == "import":
            target = p.trim_suffix(".import")
            for line in text.split("\n"):
                if line.begins_with("uid=\""):
                    uid = line.trim_prefix("uid=\"").get_slice("\"", 0)
                    break
        elif ext == "uid":
            target = p.trim_suffix(".uid")
            uid = text.strip_edges()
        if uid.begins_with("uid://") and uid != "uid://<invalid>":
            by_path[target] = uid
            if not declared.has(uid):
                declared[uid] = []
            if target not in declared[uid]:
                declared[uid].append(target)
    for uid in declared.keys():
        if declared[uid].size() > 1:
            issues.append(_issue("error", "duplicate_uid", declared[uid][0], 1, "%s is declared by %s." % [uid, ", ".join(declared[uid])], "Re-save one file from the editor (or delete its .uid/.import uid) so Godot assigns a fresh UID."))
    var refs := 0
    for path in texts.keys():
        if texts[path] == null:
            continue
        var p := str(path)
        var ext := p.get_extension()
        if ext not in ["tscn", "tres", "gd"]:
            continue
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            var line: String = lines[index]
            if ext != "gd" and index == 0:
                continue
            if ext != "gd" and line.begins_with("[ext_resource"):
                var ui := line.find(" uid=\"")
                var pi := line.find(" path=\"")
                if ui < 0:
                    continue
                refs += 1
                var uid := line.substr(ui + 6).get_slice("\"", 0)
                var rpath := line.substr(pi + 7).get_slice("\"", 0) if pi >= 0 else ""
                if by_path.has(rpath) and by_path[rpath] != uid:
                    issues.append(_issue("warning", "uid_mismatch", p, index + 1, "References %s as %s, but it declares %s." % [rpath, uid, by_path[rpath]], "Open and re-save this file in the editor so the reference picks up the current UID."))
                elif not by_path.has(rpath) and not declared.has(uid):
                    issues.append(_issue("warning", "unknown_uid", p, index + 1, "%s (%s) matches no scanned file." % [uid, rpath], "Restore the resource or fix the reference; scan the whole project if the target lives elsewhere."))
            elif ext == "gd":
                for m in _uid_re.search_all(line.get_slice("#", 0)):
                    refs += 1
                    if not declared.has(m.get_string()):
                        issues.append(_issue("warning", "unknown_uid", p, index + 1, "%s matches no scanned file." % m.get_string(), "Use a path or a UID that exists; scan the whole project if the target lives elsewhere."))
    return _finish({"declared": declared.size(), "references": refs}, issues)

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
    var lines: Array = ["# Resource UID Integrity Checker", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
