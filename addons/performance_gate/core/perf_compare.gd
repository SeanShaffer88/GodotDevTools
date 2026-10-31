## Compare supplied benchmark measurements; does not run benchmarks itself.
extends RefCounted

func run(baseline_path: String, current_path: String) -> Dictionary:
    var baseline := _read_object(baseline_path)
    var current := _read_object(current_path)
    var issues: Array = []
    if not baseline["ok"]:
        issues.append(_issue("error", "input_error", baseline_path, "Cannot read baseline JSON object.", "Provide a readable baseline JSON object."))
    if not current["ok"]:
        issues.append(_issue("error", "input_error", current_path, "Cannot read current JSON object.", "Provide a readable current JSON object."))
    if not issues.is_empty():
        return _result([], issues)
    return compare(baseline["data"], current["data"])

func _read_object(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return {"ok": false}
    return {"ok": true, "data": parser.data}

## Baseline defines metric value, unit, direction and percentage/absolute tolerances.
func compare(baseline: Dictionary, current: Dictionary) -> Dictionary:
    var rows: Array = []
    var issues: Array = []
    if typeof(baseline.get("metrics")) != TYPE_DICTIONARY or typeof(current.get("metrics")) != TYPE_DICTIONARY:
        issues.append(_issue("error", "input_error", "metrics", "Both documents must contain a metrics object.", "Provide metric objects in both files."))
        return _result(rows, issues)
    var base_metrics: Dictionary = baseline["metrics"]
    var measurements: Dictionary = current["metrics"]
    if base_metrics.is_empty():
        issues.append(_issue("error", "input_error", "baseline.metrics", "Baseline contains no metrics.", "Define at least one benchmark metric."))
        return _result(rows, issues)
    var names: Array = base_metrics.keys()
    names.sort()
    for name in names:
        var path := "metrics." + str(name)
        var spec = base_metrics[name]
        if typeof(spec) != TYPE_DICTIONARY or not _finite_number(spec.get("value")) or typeof(spec.get("unit")) != TYPE_STRING or str(spec.get("unit", "")).is_empty() or str(spec.get("direction", "")) not in ["higher_is_worse", "lower_is_worse"] or not _nonnegative_number(spec.get("tolerance_pct", 0)) or not _nonnegative_number(spec.get("tolerance_abs", 0)):
            issues.append(_issue("error", "invalid_baseline", path, "Invalid metric baseline definition.", "Provide a finite value, unit, direction and non-negative tolerances."))
            continue
        if not measurements.has(name):
            issues.append(_issue("warning", "missing_metric", path, "Metric is missing from the current run.", "Measure this metric or update the baseline intentionally."))
            continue
        var sample = measurements[name]
        if typeof(sample) != TYPE_DICTIONARY or not _finite_number(sample.get("value")) or typeof(sample.get("unit")) != TYPE_STRING:
            issues.append(_issue("error", "invalid_measurement", path, "Current metric needs a finite numeric value and unit.", "Correct the current measurement."))
            continue
        if str(sample["unit"]) != str(spec["unit"]):
            issues.append(_issue("error", "unit_mismatch", path, "Baseline and current units differ.", "Convert both measurements to the same unit."))
            continue
        var before := float(spec["value"])
        var after := float(sample["value"])
        var allowed := maxf(absf(before) * float(spec.get("tolerance_pct", 0)) / 100.0, float(spec.get("tolerance_abs", 0)))
        var worsening := after - before if spec["direction"] == "higher_is_worse" else before - after
        var regressed := worsening > allowed
        rows.append({"metric": str(name), "baseline": before, "current": after, "unit": str(spec["unit"]), "worsening": worsening, "allowance": allowed, "regressed": regressed})
        if regressed:
            issues.append(_issue("warning", "regression", path, "Worsened by %.4f %s; allowed %.4f." % [worsening, spec["unit"], allowed], "Investigate the change or update the baseline after review."))
    var extras: Array = measurements.keys()
    extras.sort()
    for name in extras:
        if not base_metrics.has(name):
            issues.append(_issue("info", "unbaselined_metric", "metrics." + str(name), "Current metric has no baseline and was not compared.", "Add a reviewed baseline if this metric should gate builds."))
    return _result(rows, issues)

func _finite_number(value) -> bool:
    return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

func _nonnegative_number(value) -> bool:
    return _finite_number(value) and float(value) >= 0.0

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func _result(rows: Array, issues: Array) -> Dictionary:
    return {"summary": {"compared": rows.size(), "issues": issues.size()}, "comparisons": rows, "issues": issues}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Performance Regression Gate", "", "Summary: " + str(result["summary"]), "", "## Comparisons"]
    for row in result["comparisons"]:
        lines.append("- `%s`: %s → %s %s; allowance %s; regression: %s" % [row["metric"], row["baseline"], row["current"], row["unit"], row["allowance"], row["regressed"]])
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
