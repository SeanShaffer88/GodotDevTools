## Wave Spawner Budget Planner - spawn timeline simulation.
## Each group spawns count enemies every interval seconds from start. An enemy
## counts as alive for its type's expected lifetime (from your playtest data).
## Reports per wave the peak alive count, the most spawns inside any one-second
## window, and spawns that land after the wave's duration.
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

const DEFAULTS := {"max_alive": 30, "max_spawn_rate": 5, "default_lifetime": 10.0}
const EPS := 0.0001


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var waves: Variant = data.get("waves")
    var life: Dictionary = data.get("enemy_lifetime", {}) if typeof(data.get("enemy_lifetime", {})) == TYPE_DICTIONARY else {}
    if typeof(waves) != TYPE_ARRAY or waves.is_empty():
        return _fail("", "Need a waves array.", "See the README for the format.", "bad_input")
    var issues: Array = []
    var rows: Array = []
    var unknown := {}
    for w in waves:
        var id := str(w.get("id", rows.size() + 1))
        var spawns: Array = []  # [time, lifetime]
        for g in w.get("groups", []):
            var enemy := str(g.get("enemy", "?"))
            var lt := float(opts["default_lifetime"])
            if life.has(enemy):
                lt = float(life[enemy])
            elif not unknown.has(enemy):
                unknown[enemy] = true
                issues.append(_issue("info", "unknown_enemy", "", 0, "No lifetime for %s; assuming %.1fs." % [enemy, lt], "Add enemy_lifetime.%s from playtest data." % enemy))
            for i in range(int(g.get("count", 0))):
                spawns.append([float(g.get("start", 0.0)) + i * float(g.get("interval", 1.0)), lt])
        spawns.sort_custom(func(a, b): return a[0] < b[0])
        var peak_alive := 0
        var peak_at := 0.0
        var peak_rate := 0
        var rate_at := 0.0
        for s in spawns:
            var t: float = s[0]
            var alive := 0
            var in_window := 0
            for o in spawns:
                if o[0] <= t + EPS and o[0] + o[1] > t + EPS:
                    alive += 1
                if o[0] >= t - EPS and o[0] < t + 1.0 - EPS:
                    in_window += 1
            if alive > peak_alive:
                peak_alive = alive
                peak_at = t
            if in_window > peak_rate:
                peak_rate = in_window
                rate_at = t
        var last: float = spawns.back()[0] if not spawns.is_empty() else 0.0
        rows.append({"wave": id, "spawns": spawns.size(), "peak_alive": peak_alive, "peak_alive_at": snappedf(peak_at, 0.01), "peak_spawns_per_second": peak_rate, "last_spawn": snappedf(last, 0.01)})
        if peak_alive > int(opts["max_alive"]):
            issues.append(_issue("warning", "alive_budget", "", 0, "Wave %s peaks at %d alive at %.1fs (budget %d)." % [id, peak_alive, peak_at, opts["max_alive"]], "Spread groups out, lower counts, or shorten time-to-kill."))
        if peak_rate > int(opts["max_spawn_rate"]):
            issues.append(_issue("warning", "spawn_rate_budget", "", 0, "Wave %s spawns %d enemies within one second from %.1fs (budget %d)." % [id, peak_rate, rate_at, opts["max_spawn_rate"]], "Stagger group start times or raise intervals; bursts cost frame time and readability."))
        if w.has("duration") and last > float(w["duration"]) + EPS:
            issues.append(_issue("warning", "wave_overrun", "", 0, "Wave %s still spawns at %.1fs, after its %.1fs duration." % [id, last, w["duration"]], "Lower count or interval, or lengthen the wave."))
    return _finish({"waves": rows.size()}, issues, {"waves": rows})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Wave | Spawns | Peak alive | Peak spawns/s | Last spawn |", "|---|---|---|---|---|"]
    for r in result.get("waves", []):
        out.append("| %s | %d | %d | %d | %.1f |" % [r["wave"], r["spawns"], r["peak_alive"], r["peak_spawns_per_second"], r["last_spawn"]])
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
    var lines: Array = ["# Wave Spawner Budget Planner", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
