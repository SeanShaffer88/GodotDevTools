extends SceneTree
const Core := preload("res://addons/golden_snapshot/core/gst_tester.gd")
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
    var result: Dictionary = op.run("res://demo/ci/golden/actual", {"golden": "res://demo/ci/golden/expected"})
    check("score change reported with its path", result["issues"].any(func(i): return i["kind"] == "changed_value" and i["message"].begins_with("$.score")))
    check("new enemy reported as added", result["issues"].any(func(i): return i["kind"] == "added_key" and i["message"].begins_with("$.enemies[2]")))
    check("float within tolerance matches", not result["issues"].any(func(i): return i["message"].begins_with("$.ratio")))
    check("output without golden noted", op._count(result, "missing_golden") == 1)
    check("golden without output flagged", op._count(result, "missing_output") == 1)
    check("tight tolerance catches the float", op.run("res://demo/ci/golden/actual", {"golden": "res://demo/ci/golden/expected", "tolerance": 0.0})["issues"].any(func(i): return i["message"].begins_with("$.ratio")))
    check("type change reported", op.evaluate({"a.json": ["{\"x\": \"1\"}", "{\"x\": 1}"]})["issues"][0]["kind"] == "type_changed")
    check("missing input is reported", op.run("res://definitely_missing_out", {"golden": "res://demo/ci/golden/expected"})["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/ci/golden/actual", {"golden": "res://demo/ci/golden/expected"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Golden Data Snapshot Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
