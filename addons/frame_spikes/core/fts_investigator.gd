## Frame-Time Spike Investigator - spike correlation.
## A frame log is {"fps_target": 60, "frames": [{frame, ms, physics_ms,
## nodes, markers}]}. A spike is a frame slower than both the frame budget
## (1000 / fps_target) and median x spike_factor. For each spike the window
## around it is searched for markers (your own labels: level loads, saves,
## spawns), node-count jumps and a dominant physics share, which are
## reported as likely causes. runtime/fts_recorder.gd records such a log
## from Performance monitors in a running game.
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

const DEFAULTS := {"spike_factor": 1.5, "window": 2, "max_miss_rate": 0.05, "node_jump": 100}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var frames: Variant = data.get("frames")
    if typeof(frames) != TYPE_ARRAY or frames.is_empty():
        return _fail("", "Frame log needs a non-empty frames array.", "Record one with runtime/fts_recorder.gd.", "bad_input")
    var budget := 1000.0 / float(data.get("fps_target", 60))
    var times: Array = frames.map(func(f): return float(f.get("ms", 0)))
    var sorted := times.duplicate()
    sorted.sort()
    var median: float = sorted[sorted.size() / 2]
    var threshold: float = max(budget, median * float(opts["spike_factor"]))
    var issues: Array = []
    var spikes: Array = []
    var misses := 0
    for i in range(frames.size()):
        var f: Dictionary = frames[i]
        if float(f.get("ms", 0)) > budget:
            misses += 1
        if float(f.get("ms", 0)) <= threshold:
            continue
        var causes: Array = []
        var w := int(opts["window"])
        for j in range(max(0, i - w), min(frames.size(), i + w + 1)):
            for m in frames[j].get("markers", []):
                causes.append("marker '%s' at frame %s" % [m, frames[j].get("frame", j)])
            if j > 0 and frames[j].has("nodes") and frames[j - 1].has("nodes"):
                var dn := int(frames[j]["nodes"]) - int(frames[j - 1]["nodes"])
                if absi(dn) >= int(opts["node_jump"]):
                    causes.append("node count %+d at frame %s" % [dn, frames[j].get("frame", j)])
        if f.has("physics_ms") and float(f["physics_ms"]) > 0.5 * float(f["ms"]):
            causes.append("physics took %.1f of %.1f ms" % [f["physics_ms"], f["ms"]])
        spikes.append({"frame": f.get("frame", i), "ms": f["ms"], "causes": causes})
        issues.append(_issue("warning", "frame_spike", "", int(f.get("frame", i)), "Frame %s took %.1f ms (median %.1f, threshold %.1f)%s." % [f.get("frame", i), f["ms"], median, threshold, (": " + "; ".join(causes)) if not causes.is_empty() else " with no recorded cause nearby"], "Profile that moment; spread the work over frames, preload, or move it to a thread." if not causes.is_empty() else "Add markers around suspect work (loads, spawns, saves) and record again."))
    var miss_rate: float = float(misses) / frames.size()
    if miss_rate > float(opts["max_miss_rate"]):
        issues.append(_issue("warning", "budget_miss_rate", "", 0, "%.1f%% of frames exceed the %.2f ms budget." % [miss_rate * 100.0, budget], "This is sustained load, not spikes: profile the steady state."))
    return _finish({"frames": frames.size(), "median_ms": snappedf(median, 0.01), "spikes": spikes.size(), "miss_rate": snappedf(miss_rate, 0.0001)}, issues, {"spikes": spikes})


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
    var lines: Array = ["# Frame-Time Spike Investigator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
