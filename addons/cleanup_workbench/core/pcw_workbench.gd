## Project Cleanup Workbench - review list, never deletion.
## Candidates in the scanned folder: assets (images, audio, models, fonts,
## scenes, resources) whose res:// path or UID appears in no text file under
## the reference root (scripts, scenes, resources, project and export
## settings); files with identical MD5; .import and .uid sidecars whose
## source file is gone; and empty folders. Paths built at runtime are
## invisible, so every candidate needs a human decision.
extends RefCounted

const EXTS: Array[String] = []
const DEFAULTS := {"root": "res://"}
const ASSET_EXTS: Array[String] = ["png", "jpg", "jpeg", "webp", "svg", "tga", "bmp", "exr", "hdr", "wav", "ogg", "mp3", "gltf", "glb", "fbx", "blend", "obj", "ttf", "otf", "woff", "woff2", "tscn", "scn", "tres", "res"]
const TEXT_EXTS: Array[String] = ["gd", "tscn", "tres", "godot", "cfg", "json", "gdshader", "gdshaderinc", "cs", "csv", "md", "txt"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var files: Array = []
    var empties: Array = []
    _all(input, files, empties)
    var texts := PackedStringArray()
    var ref_files: Array = []
    _all(str(opts["root"]), ref_files, [])
    for f in ref_files:
        if str(f).get_extension() in TEXT_EXTS:
            texts.append(FileAccess.get_file_as_string(f))
    var refs := "\n".join(texts)
    var info := {}
    for f in files:
        var uid := ""
        if FileAccess.file_exists(str(f) + ".import"):
            for line in FileAccess.get_file_as_string(str(f) + ".import").split("\n"):
                if line.begins_with("uid=\""):
                    uid = line.get_slice("\"", 1)
        elif FileAccess.file_exists(str(f) + ".uid"):
            uid = FileAccess.get_file_as_string(str(f) + ".uid").strip_edges()
        info[f] = {"md5": FileAccess.get_md5(f), "uid": uid, "exists": true}
    return evaluate(info, refs, empties)


func _all(path: String, out: Array, empties: Array) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    var count := 0
    for d in dir.get_directories():
        if d.begins_with(".") or d in ["reports", "visual_reports"]:
            continue
        count += 1
        _all(path.path_join(d), out, empties)
    for f in dir.get_files():
        count += 1
        out.append(path.path_join(f))
    if count == 0:
        empties.append(path)


## info: {path: {md5, uid}}; refs: concatenated reference text.
func evaluate(info: Dictionary, refs: String, empties: Array = []) -> Dictionary:
    var issues: Array = []
    var paths: Array = info.keys()
    paths.sort()
    var by_md5 := {}
    var known := _references(refs)
    for p in paths:
        var ext := str(p).get_extension().to_lower()
        if ext in ["import", "uid"]:
            var src := str(p).get_basename()
            if not info.has(src):
                issues.append(_issue("info", "stale_import" if ext == "import" else "orphan_uid", str(p), 0, "Sidecar for %s, which no longer exists." % src.get_file(), "Delete the sidecar after confirming the source was removed on purpose."))
            continue
        if ext not in ASSET_EXTS:
            continue
        var md5 := str(info[p]["md5"])
        if md5 != "":
            if not by_md5.has(md5):
                by_md5[md5] = []
            by_md5[md5].append(p)
        var uid := str(info[p].get("uid", ""))
        if not known.has(str(p)) and (uid == "" or not known.has(uid)):
            issues.append(_issue("info", "unused_candidate", str(p), 0, "No text file references this path or its UID.", "Confirm it is not loaded by a path built at runtime, then remove it (and its sidecars)."))
    for md5 in by_md5.keys():
        var group: Array = by_md5[md5]
        if group.size() > 1:
            issues.append(_issue("info", "duplicate_file", str(group[1]), 0, "Identical to %s." % ", ".join(group.filter(func(x): return x != group[1])), "Keep one copy and re-point references to it."))
    for e in empties:
        issues.append(_issue("info", "empty_folder", str(e), 0, "Empty folder.", "Remove it."))
    return _finish({"files": paths.size()}, issues)


## Every res:// path and uid:// id written in the reference text, as a set.
## One regex pass replaces a substring search of the whole text per asset,
## which was quadratic on large projects.
func _references(refs: String) -> Dictionary:
    var known := {}
    for m in RegEx.create_from_string("(?:res|uid)://[^\"'\\n\\r\\t)\\]]+").search_all(refs):
        known[m.get_string().strip_edges()] = true
    return known


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
    var lines: Array = ["# Project Cleanup Workbench", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
