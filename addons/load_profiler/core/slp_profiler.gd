## Startup and Scene-Load Profiler - measured load timing.
## For each scene: ResourceLoader.load with the cache bypassed for the scene
## itself (CACHE_MODE_IGNORE; dependencies may already be cached by earlier
## scenes, so order matters - the first scene pays shared costs), then
## PackedScene.instantiate and free. Reports milliseconds, direct
## dependencies and node count. Timings are from this machine and this
## process; compare on the same hardware.
extends RefCounted

const EXTS: Array[String] = ["tscn", "scn"]
const DEFAULTS := {"max_load_ms": 500.0, "max_instantiate_ms": 100.0}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var rows: Array = []
    for p in paths:
        rows.append(measure(str(p)))
    return evaluate(rows, opts)


func measure(path: String) -> Dictionary:
    var t0 := Time.get_ticks_usec()
    var res: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
    if not res is PackedScene:
        return {"path": path, "ok": false}
    var t1 := Time.get_ticks_usec()
    var node: Node = res.instantiate()
    var inst_ms := (Time.get_ticks_usec() - t1) / 1000.0
    var count := 0
    if node != null:
        count = _count_nodes(node)
        node.free()
    return {"path": path, "ok": true, "load_ms": snappedf(load_ms, 0.001), "instantiate_ms": snappedf(inst_ms, 0.001), "dependencies": ResourceLoader.get_dependencies(path).size(), "nodes": count}


func _count_nodes(n: Node) -> int:
    var c := 1
    for child in n.get_children():
        c += _count_nodes(child)
    return c


func evaluate(rows: Array, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var total := 0.0
    for r in rows:
        if not r.get("ok", false):
            issues.append(_issue("error", "load_failed", r["path"], 0, "Scene did not load.", "Run the Scene Load Smoke Tester for details."))
            continue
        total += float(r["load_ms"]) + float(r["instantiate_ms"])
        if float(r["load_ms"]) > float(opts["max_load_ms"]):
            issues.append(_issue("warning", "slow_load", r["path"], 0, "Loaded in %.1f ms (budget %.1f), %d dependencies." % [r["load_ms"], opts["max_load_ms"], r["dependencies"]], "Preload heavy dependencies during a loading screen (ResourceLoader.load_threaded_request) or split the scene."))
        if float(r["instantiate_ms"]) > float(opts["max_instantiate_ms"]):
            issues.append(_issue("warning", "slow_instantiate", r["path"], 0, "Instantiated in %.1f ms (budget %.1f), %d nodes." % [r["instantiate_ms"], opts["max_instantiate_ms"], r["nodes"]], "Reduce node count, defer optional children, or pool instances."))
    var ok_rows: Array = rows.filter(func(r): return r.get("ok", false))
    ok_rows.sort_custom(func(a, b): return float(a["load_ms"]) + float(a["instantiate_ms"]) > float(b["load_ms"]) + float(b["instantiate_ms"]))
    return _finish({"scenes": rows.size(), "total_ms": snappedf(total, 0.01)}, issues, {"scenes": ok_rows})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Scene | Load ms | Instantiate ms | Deps | Nodes |", "|---|---|---|---|---|"]
    for r in result.get("scenes", []).slice(0, 30):
        out.append("| `%s` | %.2f | %.2f | %d | %d |" % [r["path"], r["load_ms"], r["instantiate_ms"], r["dependencies"], r["nodes"]])
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
    var lines: Array = ["# Startup and Scene-Load Profiler", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
