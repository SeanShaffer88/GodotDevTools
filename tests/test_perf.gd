extends SceneTree
const Compare := preload("res://addons/performance_gate/core/perf_compare.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label)

func kinds(result: Dictionary) -> Array:
    var out: Array = []
    for issue in result["issues"]:
        out.append(issue["kind"])
    return out

func _init() -> void:
    var op = Compare.new()
    var fixture: Dictionary = op.run("res://demo/performance/baseline.json", "res://demo/performance/current.json")
    check("fixture compares two metrics", fixture["summary"]["compared"] == 2)
    check("fixture catches frame-time regression", kinds(fixture).count("regression") == 1)
    var baseline := {"metrics": {"time": {"value": 100, "unit": "ms", "direction": "higher_is_worse", "tolerance_pct": 10, "tolerance_abs": 2}}}
    check("exact tolerance passes", not kinds(op.compare(baseline, {"metrics": {"time": {"value": 110, "unit": "ms"}}})).has("regression"))
    check("past tolerance fails", kinds(op.compare(baseline, {"metrics": {"time": {"value": 111, "unit": "ms"}}})).has("regression"))
    check("improvement passes", op.compare(baseline, {"metrics": {"time": {"value": 90, "unit": "ms"}}})["issues"].is_empty())
    var lower := {"metrics": {"fps": {"value": 100, "unit": "fps", "direction": "lower_is_worse", "tolerance_abs": 5}}}
    check("lower-is-worse supported", kinds(op.compare(lower, {"metrics": {"fps": {"value": 94, "unit": "fps"}}})).has("regression"))
    var zero := {"metrics": {"errors": {"value": 0, "unit": "count", "direction": "higher_is_worse", "tolerance_pct": 10, "tolerance_abs": 2}}}
    check("zero baseline honors absolute noise", op.compare(zero, {"metrics": {"errors": {"value": 2, "unit": "count"}}})["issues"].is_empty())
    check("missing metric reported", kinds(op.compare(baseline, {"metrics": {}})).has("missing_metric"))
    check("extra metric reported", kinds(op.compare(baseline, {"metrics": {"other": {"value": 1, "unit": "ms"}}})).has("unbaselined_metric"))
    check("unit mismatch reported", kinds(op.compare(baseline, {"metrics": {"time": {"value": 100, "unit": "s"}}})).has("unit_mismatch"))
    check("invalid baseline reported", kinds(op.compare({"metrics": {"x": {"value": 1}}}, {"metrics": {}})).has("invalid_baseline"))
    check("invalid current reported", kinds(op.compare(baseline, {"metrics": {"time": {"value": "bad", "unit": "ms"}}})).has("invalid_measurement"))
    check("empty baseline rejected", kinds(op.compare({"metrics": {}}, {"metrics": {}})).has("input_error"))
    check("missing file rejected", kinds(op.run("res://missing_benchmark.json", "res://demo/performance/current.json")).has("input_error"))
    check("markdown includes metric", op.to_markdown(fixture).contains("frame_ms"))
    check("json parses", JSON.parse_string(op.to_json(fixture)).has("comparisons"))
    print("Performance Gate TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
