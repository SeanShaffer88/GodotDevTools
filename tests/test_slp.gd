extends SceneTree
const Core := preload("res://addons/load_profiler/core/slp_profiler.gd")
var op = Core.new()
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _has(result: Dictionary, kind: String, line: int) -> bool:
    for issue in result["issues"]:
        if issue["kind"] == kind and int(issue["line"]) == line:
            return true
    return false

func _init() -> void:
    var result: Dictionary = op.run("res://demo/runtime_perf")
    check("scene timed with node count", result["summary"]["scenes"] == 1 and result["scenes"][0]["nodes"] == 2)
    check("dependencies counted", result["scenes"][0]["dependencies"] == 1)
    check("generous default budget passes", result["issues"].is_empty())
    check("zero budget flags the load", op._count(op.run("res://demo/runtime_perf", {"max_load_ms": 0.0, "max_instantiate_ms": 0.0}), "slow_load") == 1)
    check("failed load reported", op.evaluate([{"path": "res://x.tscn", "ok": false}])["issues"][0]["kind"] == "load_failed")
    check("missing input is reported", op.run("res://definitely_missing_dir_slp")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/runtime_perf")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Startup and Scene-Load Profiler TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
