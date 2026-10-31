## Achievement Reachability Checker - unlock condition analysis.
## Each achievement requires one of: an event the game emits, a stat reaching
## a threshold (stats declare their maximum), or all of a list of other
## achievements. Reports conditions that reference unknown names, thresholds
## above a stat's maximum, dependency cycles, and meta-achievements blocked by
## an unreachable dependency.
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

const DEFAULTS := {}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var events: Variant = data.get("events", [])
    var stats: Variant = data.get("stats", {})
    var list: Variant = data.get("achievements")
    if typeof(list) != TYPE_ARRAY or typeof(events) != TYPE_ARRAY or typeof(stats) != TYPE_DICTIONARY:
        return _fail("", "Need events (array), stats (object) and achievements (array).", "See the README for the format.", "bad_input")
    var issues: Array = []
    var by_id := {}
    for a in list:
        var id := str(a.get("id", "")) if typeof(a) == TYPE_DICTIONARY else ""
        if id == "" or typeof(a.get("requires")) != TYPE_DICTIONARY:
            return _fail("", "Each achievement needs an id and a requires object: %s" % str(a), "Fix the entry.", "bad_input")
        if by_id.has(id):
            issues.append(_issue("warning", "duplicate_id", "", 0, "Achievement %s is defined twice." % id, "Give each achievement a unique id."))
        by_id[id] = a
    var direct := {}  # id -> true reachable ignoring deps, or false with reason already reported
    for id in by_id.keys():
        var req: Dictionary = by_id[id]["requires"]
        var ok := true
        if req.has("event"):
            if str(req["event"]) not in events:
                ok = false
                issues.append(_issue("error", "unknown_event", "", 0, "%s waits for event %s, which the game does not declare." % [id, req["event"]], "Fix the event name or declare the event."))
        elif req.has("stat"):
            var stat := str(req["stat"])
            if not stats.has(stat):
                ok = false
                issues.append(_issue("error", "unknown_stat", "", 0, "%s uses unknown stat %s." % [id, stat], "Fix the stat name or declare the stat with its maximum."))
            elif float(req.get("gte", 0)) > float(stats[stat]):
                ok = false
                issues.append(_issue("error", "unreachable_threshold", "", 0, "%s needs %s >= %s but %s is capped at %s." % [id, stat, req["gte"], stat, stats[stat]], "Lower the threshold or raise the cap."))
        elif req.has("all"):
            for dep in req["all"]:
                if not by_id.has(str(dep)):
                    ok = false
                    issues.append(_issue("error", "unknown_achievement", "", 0, "%s depends on unknown achievement %s." % [id, dep], "Fix the id or define the achievement."))
        else:
            return _fail("", "%s: requires needs event, stat or all." % id, "Fix the entry.", "bad_input")
        direct[id] = ok
    # cycles
    var in_cycle := {}
    for id in by_id.keys():
        var stack: Array = [[id, [id]]]
        while not stack.is_empty():
            var item: Array = stack.pop_back()
            var deps: Array = by_id[item[0]]["requires"].get("all", [])
            for d in deps:
                d = str(d)
                if d == id:
                    var members: Array = item[1].duplicate()
                    members.sort()
                    var key := ",".join(members)
                    if not in_cycle.has(key):
                        in_cycle[key] = true
                        issues.append(_issue("error", "achievement_cycle", "", 0, "Achievements depend on each other: %s." % " -> ".join(item[1] + [id]), "Remove one dependency so the chain has a start."))
                    for m in item[1]:
                        direct[m] = false
                elif by_id.has(d) and d not in item[1]:
                    stack.append([d, item[1] + [d]])
    # reachability fixpoint
    var reach := {}
    var changed := true
    while changed:
        changed = false
        for id in by_id.keys():
            if reach.has(id) or not direct[id]:
                continue
            var deps: Array = by_id[id]["requires"].get("all", [])
            var all_ok := true
            for d in deps:
                if not reach.has(str(d)):
                    all_ok = false
            if all_ok:
                reach[id] = true
                changed = true
    for id in by_id.keys():
        if direct[id] and not reach.has(id):
            issues.append(_issue("warning", "blocked_achievement", "", 0, "%s can never unlock because a dependency cannot." % id, "Fix the dependencies reported above."))
    return _finish({"achievements": by_id.size(), "reachable": reach.size()}, issues)


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
    var lines: Array = ["# Achievement Reachability Checker", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
