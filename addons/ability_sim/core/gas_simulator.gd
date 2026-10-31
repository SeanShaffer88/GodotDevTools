## Gameplay Ability Simulator - rotation simulation.
## Fixed-step simulation: resources regenerate each step up to their max;
## when not casting, the first ability in priority order that is off
## cooldown and affordable starts casting (cost paid at start, cooldown
## starts at cast start, damage lands when the cast finishes). At most one
## cast starts per step, so zero-time abilities are capped by the step.
## Reports casts and damage per ability, total DPS, idle time and time a
## resource sat at its maximum.
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

const DEFAULTS := {"step": 0.05, "max_idle": 0.3}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var abilities: Variant = data.get("abilities")
    if typeof(abilities) != TYPE_ARRAY or abilities.is_empty():
        return _fail("", "Need an abilities array.", "See the README for the format.", "bad_input")
    var res_def: Dictionary = data.get("resources", {})
    var res := {}
    for r in res_def.keys():
        res[r] = float(res_def[r].get("start", res_def[r].get("max", 0)))
    var by_id := {}
    for a in abilities:
        by_id[str(a["id"])] = a
    var priority: Array = data.get("priority", abilities.map(func(a): return a["id"]))
    var issues: Array = []
    for a in abilities:
        var id := str(a["id"])
        for r in a.get("cost", {}).keys():
            if not res_def.has(r) or float(a["cost"][r]) > float(res_def[r].get("max", 0)):
                issues.append(_issue("error", "never_castable", "", 0, "%s costs %s %s but the maximum is %s." % [id, a["cost"][r], r, res_def.get(r, {}).get("max", "undefined")], "Lower the cost or raise the maximum."))
        if float(a.get("cooldown", 0)) < float(a.get("cast_time", 0)):
            issues.append(_issue("info", "cooldown_below_cast", "", 0, "%s cooldown %.2fs is shorter than its %.2fs cast; the cooldown never limits it." % [id, a.get("cooldown", 0), a.get("cast_time", 0)], "Raise the cooldown or drop it."))
        if float(a.get("cooldown", 0)) <= 0.0 and float(a.get("cast_time", 0)) <= 0.0 and a.get("cost", {}).is_empty():
            issues.append(_issue("warning", "instant_spam", "", 0, "%s is free, instant and has no cooldown: it can fire every frame." % id, "Add a cooldown, cost or global cooldown."))
    var step := float(opts["step"])
    var duration := float(data.get("duration", 60))
    var ready := {}
    var casts := {}
    var damage := {}
    var casting := ""
    var cast_end := 0.0
    var idle := 0.0
    var capped := 0.0
    var t := 0.0
    while t < duration:
        for r in res.keys():
            res[r] = min(float(res_def[r].get("max", 0)), float(res[r]) + float(res_def[r].get("regen", 0)) * step)
            if is_equal_approx(float(res[r]), float(res_def[r].get("max", 0))):
                capped += step / max(1, res.size())
        if casting != "" and t + 1e-9 >= cast_end:
            damage[casting] = float(damage.get(casting, 0.0)) + float(by_id[casting].get("damage", 0))
            casting = ""
        if casting == "":
            var started := false
            for id in priority:
                if not by_id.has(id) or float(ready.get(id, 0.0)) > t + 1e-9:
                    continue
                var a: Dictionary = by_id[id]
                var ok := true
                for r in a.get("cost", {}).keys():
                    if float(res.get(r, -1.0)) < float(a["cost"][r]):
                        ok = false
                if not ok:
                    continue
                for r in a.get("cost", {}).keys():
                    res[r] = float(res[r]) - float(a["cost"][r])
                ready[id] = t + float(a.get("cooldown", 0))
                casts[id] = int(casts.get(id, 0)) + 1
                if float(a.get("cast_time", 0)) <= 0.0:
                    damage[id] = float(damage.get(id, 0.0)) + float(a.get("damage", 0))
                else:
                    casting = id
                    cast_end = t + float(a["cast_time"])
                started = true
                break
            if not started:
                idle += step
        t += step
    var total := 0.0
    for id in damage.keys():
        total += float(damage[id])
    var rows: Array = []
    for id in priority:
        if not by_id.has(id):
            continue
        rows.append({"id": id, "casts": int(casts.get(id, 0)), "damage": snappedf(float(damage.get(id, 0.0)), 0.01)})
        if int(casts.get(id, 0)) == 0 and not issues.any(func(i): return i["kind"] == "never_castable" and str(i["message"]).begins_with(id + " ")):
            issues.append(_issue("info", "never_used", "", 0, "%s was never cast in %.0fs; higher priorities always win." % [id, duration], "Move it up the priority list or remove it."))
    if idle / duration > float(opts["max_idle"]):
        issues.append(_issue("warning", "starved", "", 0, "Nothing castable %.0f%% of the time." % (idle / duration * 100.0), "Add a cheap filler ability, raise regeneration, or lower costs."))
    return _finish({"duration": duration, "dps": snappedf(total / duration, 0.01), "idle_share": snappedf(idle / duration, 0.001), "capped_share": snappedf(capped / duration, 0.001)}, issues, {"abilities": rows})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Ability | Casts | Damage |", "|---|---|---|"]
    for r in result.get("abilities", []):
        out.append("| %s | %d | %.1f |" % [r["id"], r["casts"], r["damage"]])
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
    var lines: Array = ["# Gameplay Ability Simulator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
