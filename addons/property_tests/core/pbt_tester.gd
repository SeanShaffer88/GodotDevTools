## Property-Based Gameplay Tester - generate, check, shrink.
## For each tested static function: argument generators (int/float with
## min/max, bool, choice) produce edge values first (bounds, 0, -1, 1) then
## seeded random values; the function is called and each property (a Godot
## Expression over `result` and `args`) must be true. A failing input is
## shrunk towards zero (or the nearest bound) one argument at a time,
## halving the distance, to report a minimal counterexample.
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

const DEFAULTS := {"runs": 0}


func evaluate(spec: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var script: Variant = load(str(spec.get("script", ""))) if ResourceLoader.exists(str(spec.get("script", ""))) else null
    if not script is GDScript or typeof(spec.get("tests")) != TYPE_ARRAY:
        return _fail("", "Spec needs an existing script and a tests array.", "See the README for the format.", "bad_input")
    var runs := int(opts["runs"]) if int(opts["runs"]) > 0 else int(spec.get("runs", 100))
    var rng := RandomNumberGenerator.new()
    rng.seed = int(spec.get("seed", 1))
    var issues: Array = []
    var rows: Array = []
    for t in spec["tests"]:
        var fn := str(t.get("function", ""))
        var gens: Array = t.get("args", [])
        var exprs: Array = []
        var bad := false
        for p in t.get("properties", []):
            var e := Expression.new()
            if e.parse(str(p), PackedStringArray(["result", "args"])) != OK:
                issues.append(_issue("error", "bad_spec", fn, 0, "Property '%s' does not parse: %s" % [p, e.get_error_text()], "Fix the expression (variables: result, args)."))
                bad = true
            exprs.append([str(p), e])
        if bad or not script.has_method(fn) and not _static_exists(script, fn):
            if not bad:
                issues.append(_issue("error", "bad_spec", fn, 0, "Function %s not found in the script." % fn, "Name a static function of the script."))
            continue
        var cases := _edges(gens)
        while cases.size() < runs:
            cases.append(gens.map(func(g): return _random(g, rng)))
        var failure: Variant = null
        for args in cases:
            var why := _check(script, fn, args, exprs)
            if why != "":
                failure = args
                break
        if failure == null:
            rows.append({"function": fn, "cases": cases.size(), "passed": true})
            continue
        var minimal: Array = _shrink(script, fn, failure, gens, exprs)
        var result: Variant = script.callv(fn, minimal)
        rows.append({"function": fn, "cases": cases.size(), "passed": false, "counterexample": minimal, "result": result})
        issues.append(_issue("error", "property_failed", fn, 0, "%s%s = %s breaks '%s' (first failing input %s)." % [fn, str(minimal).replace("[", "(").replace("]", ")"), result, _check(script, fn, minimal, exprs), str(failure)], "Fix the function for this input, then keep it as a regression case."))
    return _finish({"functions": rows.size(), "failed": rows.filter(func(r): return not r["passed"]).size()}, issues, {"functions": rows})


func _static_exists(script: GDScript, fn: String) -> bool:
    for m in script.get_script_method_list():
        if str(m["name"]) == fn:
            return true
    return false


func _check(script: GDScript, fn: String, args: Array, exprs: Array) -> String:
    var result: Variant = script.callv(fn, args)
    for e in exprs:
        var ok: Variant = e[1].execute([result, args])
        if e[1].has_execute_failed() or not bool(ok):
            return e[0]
    return ""


func _edges(gens: Array) -> Array:
    var columns: Array = []
    for g in gens:
        var vals: Array = []
        match str(g.get("type", "int")):
            "int", "float":
                var lo := float(g.get("min", -100))
                var hi := float(g.get("max", 100))
                for v in [lo, hi, 0.0, -1.0, 1.0]:
                    if v >= lo and v <= hi:
                        vals.append(int(v) if g["type"] == "int" else v)
            "bool":
                vals = [false, true]
            "choice":
                vals = g.get("values", [null])
        columns.append(vals)
    var out: Array = []
    var count := 0
    for c in columns:
        count = max(count, c.size())
    for i in range(count):
        out.append(columns.map(func(c): return c[min(i, c.size() - 1)]))
    return out


func _random(g: Dictionary, rng: RandomNumberGenerator) -> Variant:
    match str(g.get("type", "int")):
        "int":
            return rng.randi_range(int(g.get("min", -100)), int(g.get("max", 100)))
        "float":
            return rng.randf_range(float(g.get("min", -100)), float(g.get("max", 100)))
        "bool":
            return rng.randi() % 2 == 0
        "choice":
            var vals: Array = g.get("values", [null])
            return vals[rng.randi_range(0, vals.size() - 1)]
    return null


func _shrink(script: GDScript, fn: String, args: Array, gens: Array, exprs: Array) -> Array:
    var best := args.duplicate()
    var improved := true
    var guard := 0
    while improved and guard < 200:
        improved = false
        guard += 1
        for i in range(best.size()):
            var g: Dictionary = gens[i]
            if str(g.get("type", "int")) not in ["int", "float"]:
                continue
            var lo := float(g.get("min", -100))
            var hi := float(g.get("max", 100))
            var target := clampf(0.0, lo, hi)
            var cur := float(best[i])
            for cand in [target, cur - (cur - target) / 2.0, cur - signf(cur - target)]:
                var c: Variant = int(cand) if g["type"] == "int" else cand
                if float(c) == cur or absf(float(c) - target) >= absf(cur - target):
                    continue
                var trial := best.duplicate()
                trial[i] = c
                if _check(script, fn, trial, exprs) != "":
                    best = trial
                    improved = true
                    break
    return best


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
    var lines: Array = ["# Property-Based Gameplay Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
