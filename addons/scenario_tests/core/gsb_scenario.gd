## Gameplay Scenario Test Builder - data-driven gameplay tests.
## A scenario names a scene and a list of steps: {"frames": n} waits n
## physics frames, {"action": name, "press": bool} presses or releases an
## input action, {"call": {node, method, args}}, {"set": {node, property,
## value}}, and {"assert": {node, property, op, value}} with ops == != < <=
## > >= approx contains. runtime/gsb_runner.gd executes one step per physics
## frame against the instanced scene; the CLI runs a scenario headless and
## gates on failed assertions.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {}
const OPS: Array[String] = ["==", "!=", "<", "<=", ">", ">=", "approx", "contains"]


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var data: Variant = _read_json(input)
    if typeof(data) != TYPE_DICTIONARY:
        return _fail(input, "Scenario missing or not a JSON object.", "See the README for the format.", "bad_input")
    return _finish({"steps": data.get("steps", []).size()}, validate(data, input))


## Static validation of a scenario: [issues].
func validate(data: Dictionary, path: String = "") -> Array:
    var issues: Array = []
    if not ResourceLoader.exists(str(data.get("scene", ""))):
        issues.append(_issue("error", "bad_scenario", path, 0, "Scene %s does not exist." % data.get("scene", "(none)"), "Set \"scene\" to a res:// scene path."))
    var steps: Variant = data.get("steps")
    if typeof(steps) != TYPE_ARRAY or steps.is_empty():
        issues.append(_issue("error", "bad_scenario", path, 0, "Scenario needs a non-empty steps array.", "Add steps."))
        return issues
    for n in range(steps.size()):
        var s: Variant = steps[n]
        var ok: bool = typeof(s) == TYPE_DICTIONARY and (s.has("frames") or s.has("action") or s.has("call") or s.has("set") or s.has("assert"))
        if ok and s.has("assert"):
            ok = typeof(s["assert"]) == TYPE_DICTIONARY and str(s["assert"].get("op", "==")) in OPS and s["assert"].has("property")
        if not ok:
            issues.append(_issue("error", "bad_scenario", path, n + 1, "Step %d is not a valid frames/action/call/set/assert step." % (n + 1), "See the README for step shapes."))
    return issues


func compare(actual: Variant, op: String, expected: Variant) -> bool:
    match op:
        "==":
            return actual == expected or (typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT] and float(actual) == float(expected))
        "!=":
            return not compare(actual, "==", expected)
        "<":
            return float(actual) < float(expected)
        "<=":
            return float(actual) <= float(expected)
        ">":
            return float(actual) > float(expected)
        ">=":
            return float(actual) >= float(expected)
        "approx":
            return absf(float(actual) - float(expected)) <= 0.001
        "contains":
            return str(actual).contains(str(expected))
    return false


## Runner results -> report.
func evaluate(results: Array, path: String = "") -> Dictionary:
    var issues: Array = []
    var passed := 0
    for r in results:
        if r.get("ok", false):
            passed += 1
        else:
            issues.append(_issue("error", str(r.get("kind", "assertion_failed")), path, int(r.get("step", 0)), str(r.get("message", "")), "Check the game logic or the scenario's expectation."))
    return _finish({"checks": results.size(), "passed": passed}, issues, {"results": results})


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
    var lines: Array = ["# Gameplay Scenario Test Builder", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
