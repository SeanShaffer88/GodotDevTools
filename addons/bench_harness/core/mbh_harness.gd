## Micro-Benchmark Harness - repeated timing.
## Instantiates the benchmark script, runs each method whose name starts with
## bench_ for warm-up then timed iterations using Time.get_ticks_usec, and
## reports min, median, p95 and coefficient of variation. The report's
## "metrics" object is valid --current input for the Performance Regression
## Gate (unit us, higher is worse).
extends RefCounted

const EXTS: Array[String] = ["gd"]
const DEFAULTS := {"iterations": 30, "warmup": 5, "max_cv": 0.5}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input):
        return _fail(input, "Benchmark script not found.", "Pass --script=<path to a GDScript with bench_* methods>.", "bad_bench_script")
    var script: Variant = load(input)
    if not script is GDScript or not script.can_instantiate():
        return _fail(input, "Not an instantiable GDScript.", "Fix parse errors; the script must extend RefCounted or Node.", "bad_bench_script")
    var obj: Object = script.new()
    var names: Array = []
    for m in script.get_script_method_list():
        if str(m["name"]).begins_with("bench_") and m.get("args", []).is_empty() and str(m["name"]) not in names:
            names.append(str(m["name"]))
    names.sort()
    var samples := {}
    for n in names:
        for i in range(int(opts["warmup"])):
            obj.call(n)
        var times: Array = []
        for i in range(int(opts["iterations"])):
            var t0 := Time.get_ticks_usec()
            obj.call(n)
            times.append(Time.get_ticks_usec() - t0)
        samples[n] = times
    if obj is Node:
        obj.free()
    return evaluate(samples, input.get_file().get_basename(), opts, input)


## samples: {method: [usec, ...]} -> stats + Performance Regression Gate metrics.
func evaluate(samples: Dictionary, prefix: String = "bench", options: Dictionary = {}, path: String = "") -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    if samples.is_empty():
        issues.append(_issue("error", "no_benchmarks", path, 0, "No bench_* methods without arguments.", "Add methods named bench_something() to the script."))
        return _finish({"benchmarks": 0}, issues, {"metrics": {}, "stats": {}})
    var stats := {}
    var metrics := {}
    var names: Array = samples.keys()
    names.sort()
    for n in names:
        var t: Array = samples[n].duplicate()
        t.sort()
        var count := t.size()
        var mean := 0.0
        for v in t:
            mean += float(v)
        mean /= count
        var variance := 0.0
        for v in t:
            variance += pow(float(v) - mean, 2)
        var sd := sqrt(variance / max(1, count - 1))
        var median: float = float(t[count / 2]) if count % 2 == 1 else (float(t[count / 2 - 1]) + float(t[count / 2])) / 2.0
        var p95: float = float(t[min(count - 1, int(ceil(0.95 * count)) - 1)])
        var cv := 0.0 if mean <= 0.0 else sd / mean
        stats[n] = {"iterations": count, "min_us": t[0], "median_us": median, "p95_us": p95, "cv": snappedf(cv, 0.001)}
        metrics["%s.%s" % [prefix, n]] = {"value": median, "unit": "us", "direction": "higher_is_worse"}
        if cv > float(opts["max_cv"]):
            issues.append(_issue("info", "noisy_benchmark", path, 0, "%s spread is %.0f%% of the mean; results are unstable." % [n, cv * 100.0], "Raise iterations, make the work larger, or close other programs while benchmarking."))
    return _finish({"benchmarks": names.size()}, issues, {"metrics": metrics, "stats": stats})


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
    var lines: Array = ["# Micro-Benchmark Harness", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
