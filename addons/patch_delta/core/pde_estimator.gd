## Patch Delta Estimator - file-level build diff.
## Walks two staged build folders, pairs files by relative path, and compares
## sizes and MD5 hashes. Delta = bytes of added files + full size of changed
## files (stores and launchers usually patch by file or chunk; byte-level
## diffing would be smaller). A changed .pck is flagged because one asset
## change re-ships the whole pack.
extends RefCounted

const EXTS: Array[String] = []
const DEFAULTS := {"new": "", "max_delta": 0}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    for d in [input, str(opts["new"])]:
        if DirAccess.open(d) == null:
            return _fail(d, "Build folder not found.", "Pass --old=<folder> and --new=<folder> of staged builds.", "bad_input")
    return evaluate(_inventory(input), _inventory(str(opts["new"])), opts)


func _inventory(root: String) -> Dictionary:
    var out := {}
    var stack: Array = [root]
    while not stack.is_empty():
        var d: String = stack.pop_back()
        var dir := DirAccess.open(d)
        if dir == null:
            continue
        for sub in dir.get_directories():
            stack.append(d.path_join(sub))
        for f in dir.get_files():
            var p := d.path_join(f)
            if f.ends_with(".import"):
                continue
            var file := FileAccess.open(p, FileAccess.READ)
            out[p.trim_prefix(root).trim_prefix("/")] = {"size": file.get_length() if file else 0, "md5": FileAccess.get_md5(p)}
    return out


## old/new: {relative path: {size, md5}}
func evaluate(old: Dictionary, new: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var added: Array = []
    var removed: Array = []
    var changed: Array = []
    var delta := 0
    var keys: Array = new.keys()
    keys.sort()
    for k in keys:
        if not old.has(k):
            added.append({"path": k, "bytes": new[k]["size"]})
            delta += int(new[k]["size"])
        elif old[k]["md5"] != new[k]["md5"]:
            changed.append({"path": k, "bytes": new[k]["size"], "old_bytes": old[k]["size"]})
            delta += int(new[k]["size"])
            if str(k).get_extension() == "pck":
                issues.append(_issue("info", "monolithic_pack", k, 0, "%s changed; the whole %d-byte pack ships in the patch." % [k, new[k]["size"]], "Ship content updates as separate patch packs (export with --export-pack / PCK patching) so unchanged assets are not re-downloaded."))
    for k in old.keys():
        if not new.has(k):
            removed.append({"path": k, "bytes": old[k]["size"]})
    removed.sort_custom(func(a, b): return a["path"] < b["path"])
    if int(opts["max_delta"]) > 0 and delta > int(opts["max_delta"]):
        issues.append(_issue("warning", "delta_budget", "", 0, "Patch is about %d bytes (budget %d)." % [delta, opts["max_delta"]], "Split packs, avoid touching large unchanged files, or raise the budget."))
    return _finish({"added": added.size(), "removed": removed.size(), "changed": changed.size(), "delta_bytes": delta}, issues, {"added": added, "removed": removed, "changed": changed})


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
    var lines: Array = ["# Patch Delta Estimator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
