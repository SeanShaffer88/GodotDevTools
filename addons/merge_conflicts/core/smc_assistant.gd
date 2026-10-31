## Scene Merge Conflict Assistant - conflict explanations.
## Finds <<<<<<< / ======= / >>>>>>> hunks in Godot text files. Each hunk is
## attributed to the section it sits in (the last [node], [sub_resource],
## [ext_resource] or header line before it) and classified: the same property
## with different values on each side; ext_resource lines that reuse an id
## for different files (picking either side breaks references); the
## load_steps header count (safe to take the larger); or anything else as a
## structural conflict to resolve by hand. Files are never modified.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres", "godot", "cfg", "import"]
const DEFAULTS := {}


func conflicts(text: String) -> Array:
    var out: Array = []
    var lines := text.split("\n")
    var section := "(file header)"
    var i := 0
    while i < lines.size():
        var s := lines[i].strip_edges()
        if s.begins_with("[") and not s.begins_with("[connection"):
            section = s
        if s.begins_with("<<<<<<<"):
            var start := i + 1
            var ours: Array = []
            var theirs: Array = []
            var side := 0
            var j := i + 1
            while j < lines.size() and not lines[j].begins_with(">>>>>>>"):
                if lines[j].begins_with("======="):
                    side = 1
                elif lines[j].begins_with("|||||||"):
                    side = 2
                elif side == 0:
                    ours.append(lines[j])
                elif side == 1:
                    theirs.append(lines[j])
                j += 1
            out.append({"line": start, "section": section, "ours": ours, "theirs": theirs, "branch": lines[j].trim_prefix(">>>>>>>").strip_edges() if j < lines.size() else "?"})
            for l in ours + theirs:
                if str(l).strip_edges().begins_with("["):
                    section = str(l).strip_edges()
            i = j
        i += 1
    return out


func _props(lines: Array) -> Dictionary:
    var d := {}
    for l in lines:
        var s := str(l).strip_edges()
        if s.contains(" = ") and not s.begins_with("["):
            d[s.get_slice(" = ", 0)] = s.substr(s.get_slice(" = ", 0).length() + 3)
    return d


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var files := 0
    var total := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var hunks := conflicts(str(texts[path]))
        if hunks.is_empty():
            continue
        files += 1
        total += hunks.size()
        for h in hunks:
            var ours: Array = h["ours"]
            var theirs: Array = h["theirs"]
            var joined := "\n".join(ours + theirs)
            if ours.size() == 1 and theirs.size() == 1 and str(ours[0]).begins_with("[gd_") and str(ours[0]).contains("load_steps="):
                issues.append(_issue("info", "trivial_conflict", str(path), h["line"], "Header load_steps differs (%s vs %s)." % [str(ours[0]).get_slice("load_steps=", 1).get_slice(" ", 0), str(theirs[0]).get_slice("load_steps=", 1).get_slice(" ", 0)], "Keep the larger load_steps; Godot recomputes it on save."))
                continue
            if joined.contains("[ext_resource"):
                var ids := {}
                for l in ours:
                    if str(l).contains("[ext_resource"):
                        ids[str(l).get_slice(" id=\"", 1).get_slice("\"", 0)] = str(l).get_slice(" path=\"", 1).get_slice("\"", 0)
                var clash: Array = []
                for l in theirs:
                    var id := str(l).get_slice(" id=\"", 1).get_slice("\"", 0)
                    var p := str(l).get_slice(" path=\"", 1).get_slice("\"", 0)
                    if ids.has(id) and ids[id] != p:
                        clash.append("%s: %s vs %s" % [id, ids[id], p])
                if not clash.is_empty():
                    issues.append(_issue("error", "id_collision", str(path), h["line"], "Both sides use ext_resource id %s for different files (vs %s)." % ["; ".join(clash), h["branch"]], "Keep both lines and give one a new unique id, then update the ExtResource(\"...\") uses from that side."))
                    continue
            var po := _props(ours)
            var pt := _props(theirs)
            var shared: Array = po.keys().filter(func(k): return pt.has(k) and po[k] != pt[k])
            if not shared.is_empty() and po.size() == shared.size() and pt.size() == shared.size():
                var desc: Array = shared.map(func(k): return "%s: ours %s, theirs %s" % [k, po[k], pt[k]])
                issues.append(_issue("warning", "property_conflict", str(path), h["line"], "In %s - %s." % [h["section"], "; ".join(desc)], "Pick the intended value for each property (open the scene in the editor afterwards to confirm)."))
            else:
                issues.append(_issue("warning", "structural_conflict", str(path), h["line"], "In %s: %d line(s) ours vs %d line(s) theirs (%s)." % [h["section"], ours.size(), theirs.size(), h["branch"]], "Resolve by hand; nodes or sub-resources were added or removed on both sides."))
    return _finish({"conflicted_files": files, "hunks": total}, issues)

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
    var lines: Array = ["# Scene Merge Conflict Assistant", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
