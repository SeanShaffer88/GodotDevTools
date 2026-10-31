## Duplicate Code Detector - normalized clone detection.
## Normalizes GDScript lines (trims, drops blanks and comments, collapses
## spaces), hashes every window of min_lines consecutive lines, and merges
## overlapping matches into the longest repeated blocks. Exact clones only:
## renamed identifiers are not matched. Read-only.
extends RefCounted

const EXTS: Array[String] = ["gd"]
const DEFAULTS := {"min_lines": 6}


func normalize(text: String) -> Array:
    var out: Array = []
    var lines := text.split("\n")
    for index in range(lines.size()):
        var s := lines[index].strip_edges()
        if s == "" or s.begins_with("#"):
            continue
        if not s.contains("\""):
            s = s.get_slice("#", 0).strip_edges()
        while s.contains("  "):
            s = s.replace("  ", " ")
        if s in ["pass", "else:", "return"]:
            out.append({"text": s, "line": index + 1, "trivial": true})
        else:
            out.append({"text": s, "line": index + 1, "trivial": false})
    return out


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var n := int(opts["min_lines"])
    var issues: Array = []
    var norm := {}
    var windows := {}
    var paths: Array = texts.keys()
    paths.sort()
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := normalize(str(texts[path]))
        norm[path] = lines
        for i in range(lines.size() - n + 1):
            var key := ""
            var real := 0
            for k in range(n):
                key += lines[i + k]["text"] + "\n"
                if not lines[i + k]["trivial"]:
                    real += 1
            if real < n - 1:
                continue
            var h := key.hash()
            if not windows.has(h):
                windows[h] = []
            windows[h].append([path, i])
    # Extend matches: for each pair of locations sharing a window, grow forward.
    var seen := {}
    var groups: Array = []
    for h in windows.keys():
        var locs: Array = windows[h]
        if locs.size() < 2:
            continue
        var first: Array = locs[0]
        if seen.has("%s:%d" % first):
            continue
        var length := n
        while true:
            var ok := true
            for loc in locs:
                var arr: Array = norm[loc[0]]
                if loc[1] + length >= arr.size() or arr[loc[1] + length]["text"] != norm[first[0]][first[1] + length]["text"]:
                    ok = false
                    break
            if not ok:
                break
            length += 1
        var places: Array = []
        for loc in locs:
            for k in range(length - n + 1):
                seen["%s:%d" % [loc[0], loc[1] + k]] = true
            var arr2: Array = norm[loc[0]]
            places.append({"path": loc[0], "start": arr2[loc[1]]["line"], "end": arr2[loc[1] + length - 1]["line"]})
        groups.append({"lines": length, "places": places})
    groups.sort_custom(func(a, b): return int(a["lines"]) > int(b["lines"]))
    for g in groups:
        var others: Array = []
        for p in g["places"].slice(1):
            others.append("%s:%d" % [p["path"], p["start"]])
        var p0: Dictionary = g["places"][0]
        issues.append(_issue("info", "duplicate_block", p0["path"], p0["start"],
            "%d normalized lines (to line %d) repeat at %s." % [g["lines"], p0["end"], ", ".join(others)],
            "Extract the block into one shared function and call it from each place."))
    return _finish({"files": norm.size(), "groups": groups.size()}, issues, {"groups": groups})

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
    var lines: Array = ["# Duplicate Code Detector", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
