## Character Controller Test Course - kinematic checks.
## With constant gravity g and jump velocity v: peak height = v^2 / 2g,
## air time to land at the same height = 2v / g, horizontal reach =
## max_speed x air time (+ max_speed x coyote_time when running off an
## edge). Each ledge, gap and slope in the course is compared with those
## limits; passable obstacles with little headroom are flagged as tight.
## Coyote and jump-buffer windows shorter than two physics frames are
## flagged. Ideal-physics figures: acceleration, air control and collision
## shapes reduce real reach.
extends RefCounted

const EXTS: Array[String] = ["json"]
func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var data: Variant = _read_json(input)
    if typeof(data) != TYPE_DICTIONARY:
        return _fail(input, "Input missing or not a JSON object.", "Pass --input=<json> in the format described in the addon README.", "bad_input")
    var result: Dictionary = evaluate(data, options)
    for issue in result["issues"]:
        if issue["path"] == "":
            issue["path"] = input
    return result

const DEFAULTS := {"margin": 0.1}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var c: Variant = data.get("controller")
    var course: Variant = data.get("course")
    if typeof(c) != TYPE_DICTIONARY or typeof(course) != TYPE_ARRAY or float(c.get("gravity", 0)) <= 0.0 or float(c.get("jump_velocity", 0)) <= 0.0:
        return _fail("", "Need controller (positive gravity and jump_velocity) and a course array.", "See the README for the format.", "bad_input")
    var g := float(c["gravity"])
    var v := float(c["jump_velocity"])
    var speed := float(c.get("max_speed", 0))
    var height := v * v / (2.0 * g)
    var air := 2.0 * v / g
    var reach := speed * (air + float(c.get("coyote_time", 0)))
    var fps := float(data.get("physics_fps", 60))
    var margin := float(opts["margin"])
    var issues: Array = []
    for key in ["coyote_time", "jump_buffer"]:
        if c.has(key) and float(c[key]) > 0.0 and float(c[key]) * fps < 2.0:
            issues.append(_issue("info", "short_grace_window", "", 0, "%s %.3f s is %.1f physics frames." % [key, c[key], float(c[key]) * fps], "Use at least 2-3 frames so the window is reliably hit."))
    var rows: Array = []
    for o in course:
        var id := str(o.get("id", "?"))
        match str(o.get("type", "")):
            "ledge":
                var h := float(o.get("height", 0))
                rows.append({"id": id, "need": h, "have": height})
                if h > height:
                    issues.append(_issue("error", "unreachable_ledge", "", 0, "%s: %.1f high, but a jump peaks at %.1f." % [id, h, height], "Raise jump_velocity to at least %.1f or lower the ledge." % sqrt(2.0 * g * h)))
                elif h > height * (1.0 - margin):
                    issues.append(_issue("info", "tight_margin", "", 0, "%s: %.1f of %.1f jump height (%.0f%% headroom)." % [id, h, height, (1.0 - h / height) * 100.0], "Fine if intended as a precision jump."))
            "gap":
                var w := float(o.get("width", 0))
                rows.append({"id": id, "need": w, "have": reach})
                if w > reach:
                    issues.append(_issue("error", "unjumpable_gap", "", 0, "%s: %.1f wide, but a running jump reaches %.1f." % [id, w, reach], "Raise max_speed or jump_velocity, add coyote time, or narrow the gap."))
                elif w > reach * (1.0 - margin):
                    issues.append(_issue("info", "tight_margin", "", 0, "%s: %.1f of %.1f reach (%.0f%% headroom)." % [id, w, reach, (1.0 - w / reach) * 100.0], "Fine if intended as a precision jump."))
            "slope":
                var a := float(o.get("angle_deg", 0))
                var limit := float(c.get("floor_max_angle_deg", 45))
                rows.append({"id": id, "need": a, "have": limit})
                if a > limit:
                    issues.append(_issue("error", "too_steep_slope", "", 0, "%s: %.1f degrees, but floor_max_angle is %.1f; the character slides off." % [id, a, limit], "Lower the slope or raise floor_max_angle."))
    return _finish({"jump_height": snappedf(height, 0.01), "air_time": snappedf(air, 0.001), "jump_reach": snappedf(reach, 0.01), "obstacles": course.size()}, issues, {"course": rows})


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
    var lines: Array = ["# Character Controller Test Course", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
