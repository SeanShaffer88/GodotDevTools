## State Trace Determinism Diff - first divergence.
## Each trace is {"frames": [{"frame": n, "state": {...}}]} (or a bare array)
## recorded from two runs that should be identical (same seed, same inputs).
## Frames are matched by frame number; state is compared key by key, one
## level of nesting flattened, numbers within the tolerance. The first
## divergent frame is where to start debugging.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"second": "", "tolerance": 0.0}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var a := _load(input)
    var b := _load(str(opts["second"]))
    if a.is_empty() or b.is_empty():
        return _fail(input if a.is_empty() else str(opts["second"]), "Trace missing or not in the trace format.", "Pass --first and --second trace JSON files.", "bad_trace")
    return evaluate(a["frames"], b["frames"], opts)


func _load(path: String) -> Dictionary:
    var data: Variant = _read_json(path)
    if typeof(data) == TYPE_ARRAY:
        return {"frames": data}
    if typeof(data) == TYPE_DICTIONARY and typeof(data.get("frames")) == TYPE_ARRAY:
        return {"frames": data["frames"]}
    return {}


func _flat(state: Variant) -> Dictionary:
    var out := {}
    if typeof(state) != TYPE_DICTIONARY:
        return {"value": state}
    for k in state.keys():
        if typeof(state[k]) == TYPE_DICTIONARY:
            for k2 in state[k].keys():
                out["%s.%s" % [k, k2]] = state[k][k2]
        else:
            out[str(k)] = state[k]
    return out


func evaluate(a: Array, b: Array, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var tol := float(opts["tolerance"])
    var issues: Array = []
    var fb := {}
    for f in b:
        fb[int(f.get("frame", -1))] = f.get("state")
    var first := -1
    var keys: Array = []
    var diverged := 0
    var compared := 0
    for f in a:
        var n := int(f.get("frame", -1))
        if not fb.has(n):
            continue
        compared += 1
        var sa := _flat(f.get("state"))
        var sb := _flat(fb[n])
        var bad: Array = []
        var all_keys: Array = sa.keys()
        for k in sb.keys():
            if k not in all_keys:
                all_keys.append(k)
        all_keys.sort()
        for k in all_keys:
            var va: Variant = sa.get(k)
            var vb: Variant = sb.get(k)
            var same: bool = (typeof(va) in [TYPE_INT, TYPE_FLOAT] and typeof(vb) in [TYPE_INT, TYPE_FLOAT] and absf(float(va) - float(vb)) <= tol) or va == vb
            if not same:
                bad.append("%s: %s vs %s" % [k, va, vb])
        if not bad.is_empty():
            diverged += 1
            if first < 0:
                first = n
                keys = bad
    if first >= 0:
        issues.append(_issue("error", "divergence", "", first, "First divergence at frame %d: %s. %d of %d compared frames differ." % [first, "; ".join(keys.slice(0, 8)), diverged, compared], "Inspect what ran between frame %d and the frame before it: unseeded randomness, dictionary iteration order, delta-time or float accumulation." % first))
    if a.size() != b.size():
        issues.append(_issue("warning", "length_mismatch", "", 0, "Trace A has %d frames, trace B %d." % [a.size(), b.size()], "Record both runs for the same number of frames."))
    return _finish({"frames_compared": compared, "first_divergence": first, "frames_diverged": diverged}, issues)


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
    var lines: Array = ["# State Trace Determinism Diff", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
