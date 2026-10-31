## XP Curve Planner - time-to-level from data.
## xp_to_next[i] is the XP needed to go from level i+1 to i+2 (or a formula
## in `level` with max_level). Earn rates come from bands
## [{from_level, rate}] (XP per minute). Reports minutes per level,
## cumulative hours, and levels that take much longer than the one before.
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

const DEFAULTS := {"wall_factor": 2.0}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var table: Array = []
    if typeof(data.get("xp_to_next")) == TYPE_ARRAY:
        table = data["xp_to_next"]
    elif typeof(data.get("formula")) == TYPE_STRING and int(data.get("max_level", 0)) > 1:
        var expr := Expression.new()
        if expr.parse(str(data["formula"]), PackedStringArray(["level"])) != OK:
            return _fail("", "Formula does not parse: %s" % expr.get_error_text(), "Fix the formula (variable: level).", "bad_input")
        for level in range(1, int(data["max_level"])):
            table.append(expr.execute([level]))
    else:
        return _fail("", "Need xp_to_next (array) or formula + max_level.", "See the README for the format.", "bad_input")
    var bands: Variant = data.get("xp_per_minute")
    if typeof(bands) != TYPE_ARRAY or bands.is_empty():
        return _fail("", "Need xp_per_minute bands.", "Add [{\"from_level\": 1, \"rate\": 50}].", "bad_input")
    var sorted_bands: Array = bands.duplicate()
    sorted_bands.sort_custom(func(a, b): return int(a.get("from_level", 1)) < int(b.get("from_level", 1)))
    var issues: Array = []
    var rows: Array = []
    var cumulative := 0.0
    var prev_minutes := -1.0
    var prev_xp := -INF
    for i in range(table.size()):
        var level := i + 1
        var xp := float(table[i])
        var rate := 0.0
        for b in sorted_bands:
            if int(b.get("from_level", 1)) <= level:
                rate = float(b.get("rate", 0))
        if rate <= 0.0:
            issues.append(_issue("error", "no_rate", "", 0, "No positive XP rate covers level %d." % level, "Add a band starting at or before this level."))
            continue
        var minutes := xp / rate
        cumulative += minutes
        rows.append({"level": level, "xp_to_next": xp, "rate": rate, "minutes": snappedf(minutes, 0.01), "cumulative_hours": snappedf(cumulative / 60.0, 0.01)})
        if xp < prev_xp:
            issues.append(_issue("info", "xp_not_increasing", "", 0, "Level %d needs %s XP, less than the %s before it." % [level, xp, prev_xp], "Usually a typo; if intended (a catch-up level), ignore."))
        if prev_minutes > 0.0 and minutes > prev_minutes * float(opts["wall_factor"]):
            issues.append(_issue("warning", "level_wall", "", 0, "Level %d takes %.1f min, %.1fx the previous level." % [level, minutes, minutes / prev_minutes], "Lower its XP requirement or raise the earn rate at this band."))
        prev_minutes = minutes
        prev_xp = xp
    return _finish({"levels": rows.size(), "total_hours": snappedf(cumulative / 60.0, 0.01)}, issues, {"curve": rows})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Level | XP to next | XP/min | Minutes | Cumulative h |", "|---|---|---|---|---|"]
    for r in result.get("curve", []):
        out.append("| %d | %s | %s | %.2f | %.2f |" % [r["level"], r["xp_to_next"], r["rate"], r["minutes"], r["cumulative_hours"]])
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
    var lines: Array = ["# XP Curve Planner", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
