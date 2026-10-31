## Damage Formula Sandbox - formula grid evaluation.
## Parses the formula with Godot's Expression class, evaluates it for every
## combination of the listed stat values, and checks results against the
## expected minimum and maximum, finiteness, and declared monotonicity
## (increasing or decreasing in a stat with the others held fixed).
## The formula is your own data; it runs with no base object.
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

const DEFAULTS := {"max_combinations": 100000}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var formula: Variant = data.get("formula")
    var vars: Variant = data.get("vars")
    if typeof(formula) != TYPE_STRING or typeof(vars) != TYPE_DICTIONARY or vars.is_empty():
        return _fail("", "Need a \"formula\" string and a non-empty \"vars\" object.", "See the README for the format.", "bad_input")
    var names: Array = vars.keys()
    names.sort()
    var total := 1
    for n in names:
        if typeof(vars[n]) != TYPE_ARRAY or vars[n].is_empty():
            return _fail("", "vars.%s must be a non-empty array of numbers." % n, "List the stat values to test.", "bad_input")
        total *= vars[n].size()
    if total > int(opts["max_combinations"]):
        return _fail("", "%d combinations exceed the cap of %d." % [total, opts["max_combinations"]], "Use fewer sample values per stat or raise --max-combinations.", "bad_input")
    var expr := Expression.new()
    if expr.parse(str(formula), PackedStringArray(names)) != OK:
        return _finish({"combinations": 0}, [_issue("error", "eval_error", "", 0, "Formula does not parse: %s" % expr.get_error_text(), "Fix the formula syntax (Godot Expression rules).")])
    var expect: Dictionary = data.get("expect", {}) if typeof(data.get("expect", {})) == TYPE_DICTIONARY else {}
    var issues: Array = []
    var results := {}
    var low := INF
    var high := -INF
    var neg: Array = []
    var over: Array = []
    for i in range(total):
        var combo := _combo(i, names, vars)
        var value: Variant = expr.execute(combo.values(), null, false)
        if expr.has_execute_failed() or typeof(value) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(value)) or is_inf(float(value)):
            issues.append(_issue("error", "eval_error", "", 0, "Formula failed or was not finite at %s." % str(combo), "Guard divisions and invalid inputs in the formula."))
            continue
        var v := float(value)
        results[i] = v
        low = min(low, v)
        high = max(high, v)
        if expect.has("min") and v < float(expect["min"]):
            neg.append([v, combo])
        if expect.has("max") and v > float(expect["max"]):
            over.append([v, combo])
    if not neg.is_empty():
        neg.sort_custom(func(a, b): return a[0] < b[0])
        issues.append(_issue("warning", "negative_result", "", 0, "%d of %d combinations fall below %s; worst %.2f at %s." % [neg.size(), total, expect["min"], neg[0][0], str(neg[0][1])], "Clamp the result (max(%s, ...)) or rework the term that subtracts." % expect["min"]))
    if not over.is_empty():
        over.sort_custom(func(a, b): return a[0] > b[0])
        issues.append(_issue("warning", "overflow", "", 0, "%d of %d combinations exceed %s; worst %.2f at %s." % [over.size(), total, expect["max"], over[0][0], str(over[0][1])], "Cap the result or reduce the multiplying terms."))
    var mono: Dictionary = expect.get("monotonic", {}) if typeof(expect.get("monotonic", {})) == TYPE_DICTIONARY else {}
    for stat in mono.keys():
        if stat not in names:
            continue
        var idx := names.find(stat)
        var stride := 1
        for k in range(idx + 1, names.size()):
            stride *= vars[names[k]].size()
        var size: int = vars[stat].size()
        var increasing: bool = str(mono[stat]) == "increasing"
        var bad := 0
        var example := {}
        for i in range(total):
            if int(i / stride) % size == size - 1:
                continue
            var j := i + stride
            if not results.has(i) or not results.has(j):
                continue
            var ok: bool = results[j] >= results[i] if increasing else results[j] <= results[i]
            if not ok:
                bad += 1
                if example.is_empty():
                    example = _combo(i, names, vars)
        if bad > 0:
            issues.append(_issue("warning", "non_monotonic", "", 0, "Result is not %s in %s in %d steps, e.g. from %s." % [mono[stat], stat, bad, str(example)], "Check terms that change sign or saturate as %s grows." % stat))
    return _finish({"combinations": total, "min": snappedf(low, 0.001) if low != INF else null, "max": snappedf(high, 0.001) if high != -INF else null}, issues)


func _combo(i: int, names: Array, vars: Dictionary) -> Dictionary:
    var combo := {}
    var rest := i
    for k in range(names.size() - 1, -1, -1):
        var arr: Array = vars[names[k]]
        combo[names[k]] = arr[rest % arr.size()]
        rest = int(rest / arr.size())
    var ordered := {}
    for n in names:
        ordered[n] = combo[n]
    return ordered


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
    var lines: Array = ["# Damage Formula Sandbox", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
