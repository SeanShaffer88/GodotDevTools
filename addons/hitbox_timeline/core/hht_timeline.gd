## Hitbox and Hurtbox Timeline Viewer - combat windows.
## Finds value tracks on ":disabled" (CollisionShape) or ":monitoring" /
## ":monitorable" (Area) properties in Animation resources and turns their
## keys into active windows (seconds and physics frames). Flags hitboxes
## still active when the animation ends, windows shorter than one physics
## frame (physics may never see them), and hurtbox-off windows
## (invulnerability) for review.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres"]
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
const DEFAULTS := {"physics_fps": 60, "hurt_pattern": "hurt"}


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var fps := float(opts["physics_fps"])
    var issues: Array = []
    var timelines: Array = []
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        var lines := (text + "\n[end]").split("\n")
        var in_anim := false
        var name := ""
        var length := 1.0
        var tracks := {}
        var i := 0
        while i < lines.size():
            var s := lines[i].strip_edges()
            if s.begins_with("["):
                if in_anim:
                    _timeline(str(path), name, length, tracks, fps, str(opts["hurt_pattern"]), issues, timelines)
                in_anim = (s.begins_with("[sub_resource") and s.contains("type=\"Animation\"")) or (s == "[resource]" and text.begins_with("[gd_resource type=\"Animation\""))
                name = s.get_slice("id=\"", 1).get_slice("\"", 0) if s.contains("id=\"") else str(path).get_file().get_basename()
                length = 1.0
                tracks = {}
            elif in_anim:
                if s.begins_with("resource_name = "):
                    name = s.get_slice("\"", 1)
                elif s.begins_with("length = "):
                    length = float(s.get_slice(" = ", 1))
                else:
                    var m := RegEx.create_from_string("^tracks/(\\d+)/(path|keys) = (.*)$").search(s)
                    if m != null:
                        var idx := int(m.get_string(1))
                        if not tracks.has(idx):
                            tracks[idx] = {"line": i + 1}
                        var value := m.get_string(3)
                        if m.get_string(2) == "keys" and value.ends_with("{"):
                            var j := i + 1
                            while j < lines.size() and lines[j].strip_edges() != "}":
                                value += "\n" + lines[j]
                                j += 1
                            i = j
                        tracks[idx][m.get_string(2)] = value
            i += 1
    return _finish({"timelines": timelines.size()}, issues, {"timelines": timelines})


func _timeline(path: String, anim: String, length: float, tracks: Dictionary, fps: float, hurt: String, issues: Array, out: Array) -> void:
    for idx in tracks.keys():
        var t: Dictionary = tracks[idx]
        var target := str(t.get("path", "")).replace("NodePath(", "").replace(")", "").replace("\"", "")
        var prop := target.get_slice(":", 1)
        if prop not in ["disabled", "monitoring", "monitorable"] or not t.has("keys"):
            continue
        var keys := str(t["keys"])
        var times: Array = Array(keys.get_slice("\"times\": PackedFloat32Array(", 1).get_slice(")", 0).split(",", false)).map(func(x): return float(x))
        var vt := keys.get_slice("\"values\": ", 1)
        var values := split_values(vt.substr(0, vt.rfind("]") + 1))
        var windows: Array = []
        var start := -1.0
        for k in range(min(times.size(), values.size())):
            var active: bool = (values[k] == "false") if prop == "disabled" else (values[k] == "true")
            if active and start < 0.0:
                start = times[k]
            elif not active and start >= 0.0:
                windows.append([start, times[k]])
                start = -1.0
        var open_end := start >= 0.0
        if open_end:
            windows.append([start, length])
        var node := target.get_slice(":", 0)
        var is_hurt := node.to_lower().contains(hurt)
        out.append({"path": path, "animation": anim, "node": node, "hurtbox": is_hurt, "windows": windows.map(func(w): return {"from": w[0], "to": w[1], "frames": snappedf((w[1] - w[0]) * fps, 0.1)})})
        if is_hurt:
            var off_start := -1.0
            for k in range(min(times.size(), values.size())):
                var active2: bool = (values[k] == "false") if prop == "disabled" else (values[k] == "true")
                if not active2 and off_start < 0.0:
                    off_start = times[k]
                elif active2 and off_start >= 0.0:
                    issues.append(_issue("info", "invulnerable_window", path, int(t["line"]), "%s/%s: hurtbox off %.2f-%.2fs (%.1f frames)." % [anim, node, off_start, times[k], (times[k] - off_start) * fps], "Confirm the invulnerability window is intended."))
                    off_start = -1.0
            continue
        if open_end:
            issues.append(_issue("warning", "stays_active", path, int(t["line"]), "%s/%s: active from %.2fs and still active when the animation ends (%.2fs)." % [anim, node, start, length], "Add a key that disables it before the end, or the hitbox keeps hurting after the attack."))
        for w in windows:
            if (w[1] - w[0]) * fps < 1.0:
                issues.append(_issue("warning", "window_too_short", path, int(t["line"]), "%s/%s: active %.3fs (%.2f physics frames); collisions may never register." % [anim, node, w[1] - w[0], (w[1] - w[0]) * fps], "Keep hit windows at least one physics frame (%.3fs at %d Hz)." % [1.0 / fps, int(fps)]))

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
    var lines: Array = ["# Hitbox and Hurtbox Timeline Viewer", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
