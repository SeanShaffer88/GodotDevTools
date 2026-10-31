## AI Perception Debugger - traced perception decisions.
## For each agent and target: distance, angle from the agent's facing,
## whether it is inside sight range and half the field of view, and whether
## any wall segment blocks the line of sight (Geometry2D segment
## intersection). Hearing succeeds within hearing_range x noise, multiplied
## by wall_muffle for every wall crossed. Every decision is traced with its
## numbers, and expectations in the scenario are checked. Mirror your game's
## perception rules in the scenario; this is a model, not your AI code.
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

const DEFAULTS := {"wall_muffle": 0.5}


func _v(a: Variant) -> Vector2:
    return Vector2(float(a[0]), float(a[1]))


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var agents: Variant = data.get("agents")
    var targets: Variant = data.get("targets")
    if typeof(agents) != TYPE_ARRAY or typeof(targets) != TYPE_ARRAY:
        return _fail("", "Need agents and targets arrays.", "See the README for the format.", "bad_input")
    var walls: Array = data.get("walls", [])
    var trace := {}
    for a in agents:
        var ap := _v(a["pos"])
        var facing := Vector2.RIGHT.rotated(deg_to_rad(float(a.get("facing_deg", 0))))
        for t in targets:
            var tp := _v(t["pos"])
            var d := ap.distance_to(tp)
            var angle := rad_to_deg(absf(facing.angle_to(tp - ap))) if d > 0.0 else 0.0
            var crossed := 0
            var blocker := -1
            for w in range(walls.size()):
                var seg: Array = walls[w]
                if Geometry2D.segment_intersects_segment(ap, tp, Vector2(seg[0], seg[1]), Vector2(seg[2], seg[3])) != null:
                    crossed += 1
                    if blocker < 0:
                        blocker = w
            var in_range: bool = d <= float(a.get("sight_range", 0))
            var in_fov: bool = angle <= float(a.get("fov_deg", 0)) / 2.0
            var sees: bool = in_range and in_fov and crossed == 0
            var hear_range := float(a.get("hearing_range", 0)) * float(t.get("noise", 1.0)) * pow(float(opts["wall_muffle"]), crossed)
            var hears: bool = d <= hear_range
            var why: Array = []
            why.append("distance %.1f %s sight range %.1f" % [d, "<=" if in_range else ">", a.get("sight_range", 0)])
            why.append("angle %.1f %s half FOV %.1f" % [angle, "<=" if in_fov else ">", float(a.get("fov_deg", 0)) / 2.0])
            why.append("line of sight clear" if crossed == 0 else "wall %d blocks line of sight" % blocker)
            why.append("hearing range %.1f after %d wall(s): %s" % [hear_range, crossed, "heard" if hears else "not heard"])
            trace["%s>%s" % [a["id"], t["id"]]] = {"sees": sees, "hears": hears, "distance": snappedf(d, 0.01), "angle": snappedf(angle, 0.01), "walls_crossed": crossed, "why": why}
    var issues: Array = []
    for e in data.get("expect", []):
        var key := "%s>%s" % [e.get("agent", "?"), e.get("target", "?")]
        if not trace.has(key):
            issues.append(_issue("error", "unknown_reference", "", 0, "Expectation names unknown pair %s." % key, "Fix the agent or target id."))
            continue
        for sense in ["sees", "hears"]:
            if e.has(sense) and bool(e[sense]) != trace[key][sense]:
                issues.append(_issue("warning", "expectation_failed", "", 0, "%s: expected %s = %s, got %s (%s)." % [key, sense, e[sense], trace[key][sense], "; ".join(trace[key]["why"])], "Adjust the scenario's tuning (range, FOV, positions) or the expectation, then mirror the change in the game."))
    return _finish({"pairs": trace.size(), "seen": trace.values().filter(func(x): return x["sees"]).size()}, issues, {"trace": trace})


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
    var lines: Array = ["# AI Perception Debugger", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
