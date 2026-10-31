## Animation Performance Auditor - track and key hygiene.
## Parses Animation resources (sub-resources in scenes and .tres files) and,
## for value tracks, compares key values as text: a track whose keys are all
## equal is constant (a property set once would do), an interior key equal to
## both neighbours on a linear/step track is redundant, and two keys at the
## same time are duplicates. Fewer tracks and keys mean less work per
## animation update.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres"]
const DEFAULTS := {"max_tracks": 64}


## Split a bracketed value list at top-level commas: "[A(1, 2), B]" -> ["A(1, 2)", "B"].
func split_values(text: String) -> Array:
    var inner := text.strip_edges().trim_prefix("[").trim_suffix("]")
    var out: Array = []
    var depth := 0
    var cur := ""
    var in_str := false
    for c in inner:
        if c == "\"":
            in_str = not in_str
        if not in_str and c in ["(", "[", "{"]:
            depth += 1
        elif not in_str and c in [")", "]", "}"]:
            depth -= 1
        if c == "," and depth == 0 and not in_str:
            out.append(cur.strip_edges())
            cur = ""
        else:
            cur += c
    if cur.strip_edges() != "":
        out.append(cur.strip_edges())
    return out


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var anims := 0
    var track_total := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := (str(texts[path]) + "\n[end]").split("\n")
        var in_anim := false
        var name := ""
        var tracks := {}
        var start_line := 0
        var i := 0
        while i < lines.size():
            var s := lines[i].strip_edges()
            if s.begins_with("["):
                if in_anim:
                    anims += 1
                    track_total += tracks.size()
                    _check_anim(str(path), name, start_line, tracks, opts, issues)
                in_anim = (s.begins_with("[sub_resource") and s.contains("type=\"Animation\"")) or (s == "[resource]" and str(texts[path]).begins_with("[gd_resource type=\"Animation\""))
                name = s.get_slice("id=\"", 1).get_slice("\"", 0) if s.contains("id=\"") else str(path).get_file()
                tracks = {}
                start_line = i + 1
            elif in_anim:
                var m := RegEx.create_from_string("^tracks/(\\d+)/(\\w+) = (.*)$").search(s)
                if s.begins_with("resource_name = "):
                    name = s.get_slice("\"", 1)
                elif m != null:
                    var idx := int(m.get_string(1))
                    if not tracks.has(idx):
                        tracks[idx] = {"line": i + 1}
                    var value := m.get_string(3)
                    if m.get_string(2) == "keys" and value.ends_with("{"):
                        var j := i + 1
                        while j < lines.size() and lines[j].strip_edges() != "}":
                            value += "\n" + lines[j]
                            j += 1
                        value += "\n}"
                        i = j
                    tracks[idx][m.get_string(2)] = value
            i += 1
    return _finish({"animations": anims, "tracks": track_total}, issues)


func _check_anim(path: String, name: String, line: int, tracks: Dictionary, opts: Dictionary, issues: Array) -> void:
    if tracks.size() > int(opts["max_tracks"]):
        issues.append(_issue("warning", "track_budget", path, line, "Animation %s has %d tracks (budget %d)." % [name, tracks.size(), opts["max_tracks"]], "Split it or drop tracks that do not change."))
    for idx in tracks.keys():
        var t: Dictionary = tracks[idx]
        if str(t.get("type", "")).replace("\"", "") != "value" or not t.has("keys"):
            continue
        var keys := str(t["keys"])
        var times_text := keys.get_slice("\"times\": PackedFloat32Array(", 1).get_slice(")", 0)
        var times: Array = Array(times_text.split(",", false)).map(func(x): return float(x))
        var values_text := keys.get_slice("\"values\": ", 1)
        var values := split_values(values_text.substr(0, values_text.rfind("]") + 1))
        var label := str(t.get("path", "track %d" % idx)).replace("NodePath(", "").replace(")", "").replace("\"", "")
        var interp := int(str(t.get("interp", "1")))
        if values.size() < 2:
            continue
        for k in range(1, times.size()):
            if is_equal_approx(float(times[k]), float(times[k - 1])):
                issues.append(_issue("warning", "duplicate_time_key", path, int(t["line"]), "%s/%s: two keys at %.3fs." % [name, label, times[k]], "Delete one; overlapping keys make the pose at that time ambiguous."))
        var all_same := true
        for v in values:
            if v != values[0]:
                all_same = false
        if all_same:
            issues.append(_issue("info", "constant_track", path, int(t["line"]), "%s/%s: all %d keys are %s." % [name, label, values.size(), values[0]], "Remove the track and set the property once (or keep one key)."))
            continue
        if interp in [0, 1]:
            var redundant := 0
            for k in range(1, values.size() - 1):
                if values[k] == values[k - 1] and values[k] == values[k + 1]:
                    redundant += 1
            if redundant > 0:
                issues.append(_issue("info", "redundant_keys", path, int(t["line"]), "%s/%s: %d interior keys equal both neighbours." % [name, label, redundant], "Delete them; the curve is unchanged."))

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
    var lines: Array = ["# Animation Performance Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
