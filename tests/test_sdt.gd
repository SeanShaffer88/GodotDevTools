extends SceneTree
const Core := preload("res://addons/trace_diff/core/sdt_diff.gd")
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
    var result: Dictionary = op.run("res://demo/ci/traces/run_a.json", {"second": "res://demo/ci/traces/run_b.json"})
    check("first divergence at frame 6", result["summary"]["first_divergence"] == 6)
    check("diverging key named", result["issues"].any(func(i): return i["kind"] == "divergence" and i["message"].contains("x: ")))
    check("three frames differ", result["summary"]["frames_diverged"] == 3)
    check("length mismatch reported", op._count(result, "length_mismatch") == 1)
    check("tolerance absorbs small drift", op.run("res://demo/ci/traces/run_a.json", {"second": "res://demo/ci/traces/run_b.json", "tolerance": 0.5})["summary"]["first_divergence"] == 7)
    check("identical traces match", op.evaluate([{"frame": 0, "state": {"a": {"b": 1}}}], [{"frame": 0, "state": {"a": {"b": 1}}}])["issues"].is_empty())
    check("missing input is reported", op.run("res://definitely_missing.json", {"second": "res://demo/ci/traces/run_b.json"})["issues"][0]["kind"] == "bad_trace")
    var r: Dictionary = op.run("res://demo/ci/traces/run_a.json", {"second": "res://demo/ci/traces/run_b.json"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("State Trace Determinism Diff TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
