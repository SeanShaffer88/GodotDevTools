## Difficulty Curve Analyzer - power ratio per level.
## ratio = enemy_power / player_power for each level, using numbers your own
## balance sheet defines. Flags jumps and drops between consecutive levels and
## levels beyond a ceiling ratio. The numbers mean whatever your game says
## power means; the tool only reads their shape.
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

const DEFAULTS := {"spike": 0.25, "dip": 0.25, "max_ratio": 1.5}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var levels: Variant = data.get("levels")
    if typeof(levels) != TYPE_ARRAY or levels.is_empty():
        return _fail("", "Missing \"levels\" array.", "See the README for the format.", "bad_input")
    var issues: Array = []
    var rows: Array = []
    var prev_ratio := -1.0
    var prev_level := -INF
    for entry in levels:
        if typeof(entry) != TYPE_DICTIONARY or not entry.has("level") or float(entry.get("player_power", 0)) <= 0.0 or not entry.has("enemy_power"):
            return _fail("", "Every level needs level, enemy_power and a positive player_power.", "Fix the entry: %s" % str(entry), "bad_input")
        var level: float = float(entry["level"])
        var ratio: float = float(entry["enemy_power"]) / float(entry["player_power"])
        rows.append({"level": entry["level"], "ratio": snappedf(ratio, 0.001)})
        if level <= prev_level:
            issues.append(_issue("warning", "level_order", "", 0, "Level %s follows level %s." % [entry["level"], prev_level], "Sort levels ascending so changes compare neighbours."))
        if ratio > float(opts["max_ratio"]):
            issues.append(_issue("warning", "too_hard", "", 0, "Level %s ratio %.2f exceeds %.2f." % [entry["level"], ratio, opts["max_ratio"]], "Lower enemy power or give the player more power before this level."))
        if prev_ratio >= 0.0:
            var delta := ratio - prev_ratio
            if delta > float(opts["spike"]):
                issues.append(_issue("warning", "difficulty_spike", "", 0, "Level %s: ratio jumps %.2f -> %.2f (+%.2f)." % [entry["level"], prev_ratio, ratio, delta], "Smooth enemy power across the surrounding levels or add a power reward just before."))
            elif -delta > float(opts["dip"]):
                issues.append(_issue("info", "difficulty_dip", "", 0, "Level %s: ratio drops %.2f -> %.2f (%.2f)." % [entry["level"], prev_ratio, ratio, delta], "A deliberate breather is fine; otherwise raise enemy power here."))
        prev_ratio = ratio
        prev_level = level
    return _finish({"levels": rows.size()}, issues, {"curve": rows})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Level | Ratio |", "|---|---|"]
    for r in result.get("curve", []):
        out.append("| %s | %.3f |" % [r["level"], r["ratio"]])
    out.append("")
    return out


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
    var lines: Array = ["# Difficulty Curve Analyzer", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
