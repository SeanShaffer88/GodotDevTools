## Random Table Fairness Tester - chi-square goodness of fit.
## For each table, compares observed outcome counts (from logs or a
## recorded session) with counts expected from the intended weights using
## Pearson's chi-square statistic, k-1 degrees of freedom, and the upper
## regularized incomplete gamma function for the p-value. A small p-value
## means the recorded results are unlikely under the intended odds.
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

const DEFAULTS := {"alpha": 0.01}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var tables: Variant = data.get("tables")
    if typeof(tables) != TYPE_DICTIONARY:
        return _fail("", "Need a tables object.", "See the README for the format.", "bad_input")
    var issues: Array = []
    var out := {}
    var names: Array = tables.keys()
    names.sort()
    for name in names:
        var t: Variant = tables[name]
        if typeof(t) != TYPE_DICTIONARY or typeof(t.get("weights")) != TYPE_DICTIONARY or typeof(t.get("observed")) != TYPE_DICTIONARY:
            return _fail("", "Table %s needs weights and observed objects." % name, "See the README.", "bad_input")
        var weights: Dictionary = t["weights"]
        var observed: Dictionary = t["observed"]
        for k in observed.keys():
            if not weights.has(k):
                issues.append(_issue("error", "unknown_outcome", "", 0, "%s: observed outcome %s has no weight." % [name, k], "Fix the log mapping or add the outcome to the table."))
        var total_w := 0.0
        var n := 0.0
        for k in weights.keys():
            total_w += float(weights[k])
            n += float(observed.get(k, 0))
        if total_w <= 0.0 or n <= 0.0 or weights.size() < 2:
            continue
        var chi := 0.0
        var min_expected := INF
        for k in weights.keys():
            var e := n * float(weights[k]) / total_w
            min_expected = min(min_expected, e)
            if e > 0.0:
                chi += pow(float(observed.get(k, 0)) - e, 2) / e
        var dof := weights.size() - 1
        var p := gamma_q(dof / 2.0, chi / 2.0)
        out[name] = {"n": int(n), "chi_square": snappedf(chi, 0.0001), "dof": dof, "p_value": p}
        if min_expected < 5.0:
            issues.append(_issue("warning", "low_sample", "", 0, "%s: smallest expected count is %.1f (< 5); the test is unreliable with %d samples." % [name, min_expected, int(n)], "Record more outcomes before judging fairness."))
        elif p < float(opts["alpha"]):
            issues.append(_issue("warning", "unfair_distribution", "", 0, "%s: chi-square %.2f, dof %d, p = %s < %s. Recorded results are unlikely under the intended weights." % [name, chi, dof, String.num_scientific(p), opts["alpha"]], "Check the selection code (off-by-one ranges, integer weights, re-rolls, pity overrides) against the table."))
    return _finish({"tables": out.size()}, issues, {"tables": out})


## Upper regularized incomplete gamma Q(a, x) (Numerical Recipes gser/gcf).
func gamma_q(a: float, x: float) -> float:
    if x <= 0.0:
        return 1.0
    if x < a + 1.0:
        var ap := a
        var sum := 1.0 / a
        var del := sum
        for i in range(500):
            ap += 1.0
            del *= x / ap
            sum += del
            if absf(del) < absf(sum) * 1e-14:
                break
        return 1.0 - sum * exp(-x + a * log(x) - lgamma(a))
    var b := x + 1.0 - a
    var c := 1.0 / 1e-300
    var d := 1.0 / b
    var h := d
    for i in range(1, 500):
        var an := -i * (i - a)
        b += 2.0
        d = an * d + b
        if absf(d) < 1e-300:
            d = 1e-300
        c = b + an / c
        if absf(c) < 1e-300:
            c = 1e-300
        d = 1.0 / d
        var delta := d * c
        h *= delta
        if absf(delta - 1.0) < 1e-14:
            break
    return exp(-x + a * log(x) - lgamma(a)) * h


## log Gamma via Lanczos (g = 7, n = 9).
func lgamma(z: float) -> float:
    var coef := [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
        -176.61503916999185, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7]
    if z < 0.5:
        return log(PI / absf(sin(PI * z))) - lgamma(1.0 - z)
    z -= 1.0
    var x: float = coef[0]
    for i in range(1, 9):
        x += coef[i] / (z + i)
    var t := z + 7.5
    return 0.5 * log(2.0 * PI) + (z + 0.5) * log(t) - t + log(x)


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
    var lines: Array = ["# Random Table Fairness Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
