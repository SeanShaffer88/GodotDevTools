## Save File Bloat Auditor - save size by key.
## Reads sample JSON saves (file-name order = play order), measures each
## top-level key and each key one level down by the size of its compact JSON,
## and compares the first and last samples to find keys that grow with play
## time - the usual cause of saves that get slower every session.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"max_bytes": 1048576, "dominant_share": 0.5, "growth_factor": 4.0}


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var samples: Array = []
    var paths: Array = texts.keys()
    paths.sort()
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var data: Variant = JSON.parse_string(str(texts[path]))
        if typeof(data) != TYPE_DICTIONARY:
            issues.append(_issue("error", "bad_input", str(path), 0, "Not a JSON object save.", "Only JSON object saves are measured."))
            continue
        var total := str(texts[path]).to_utf8_buffer().size()
        var keys := measure(data)
        samples.append({"path": str(path), "bytes": total, "keys": keys})
        if total > int(opts["max_bytes"]):
            issues.append(_issue("warning", "save_over_budget", str(path), 0, "Save is %d bytes (budget %d)." % [total, opts["max_bytes"]], "Trim the largest keys listed in the report."))
        var compact := JSON.stringify(data).length()
        for k in keys.keys():
            if not str(k).contains("/") and compact > 0 and float(keys[k]) / compact > float(opts["dominant_share"]):
                issues.append(_issue("warning", "key_dominates", str(path), 0, "%s is %.0f%% of the save (%d bytes)." % [k, 100.0 * keys[k] / compact, keys[k]], "Cap, compress, or move this data out of the save (logs and history usually belong elsewhere)."))
    if samples.size() >= 2:
        var first: Dictionary = samples[0]["keys"]
        var last: Dictionary = samples.back()["keys"]
        for k in last.keys():
            var before := int(first.get(k, 0))
            if before > 0 and float(last[k]) / before >= float(opts["growth_factor"]) and int(last[k]) > 256:
                issues.append(_issue("warning", "key_growth", samples.back()["path"], 0, "%s grew %.1fx (%d -> %d bytes) between %s and %s." % [k, float(last[k]) / before, before, last[k], samples[0]["path"].get_file(), samples.back()["path"].get_file()], "Make this collection bounded (ring buffer, pruning) so saves stop growing with play time."))
    return _finish({"samples": samples.size()}, issues, {"samples": samples})


## Compact-JSON byte size of each top-level key and each key one level down ("a/b").
func measure(data: Dictionary) -> Dictionary:
    var out := {}
    for k in data.keys():
        out[str(k)] = JSON.stringify(data[k]).to_utf8_buffer().size()
        if typeof(data[k]) == TYPE_DICTIONARY:
            for k2 in data[k].keys():
                out["%s/%s" % [k, k2]] = JSON.stringify(data[k][k2]).to_utf8_buffer().size()
    return out


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = []
    for s in result.get("samples", []):
        out.append("### %s (%d bytes)" % [s["path"], s["bytes"]])
        var keys: Array = s["keys"].keys()
        keys.sort_custom(func(a, b): return int(s["keys"][a]) > int(s["keys"][b]))
        for k in keys.slice(0, 10):
            out.append("- %s: %d" % [k, s["keys"][k]])
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
    var lines: Array = ["# Save File Bloat Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
