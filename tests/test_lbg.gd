extends SceneTree
const Core := preload("res://addons/log_budget/core/lbg_gate.gd")
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
    var result: Dictionary = op.run("res://demo/ci/logs/run.log", {"baseline": "res://demo/ci/logs/baseline.json"})
    check("errors over baseline", op._count(result, "error_budget") == 1)
    check("warnings over baseline", op._count(result, "warning_budget") == 1)
    check("two new signatures", op._count(result, "new_signature") == 2)
    check("suggested baseline offered", result["suggested_baseline"]["errors"] == 5 and result["suggested_baseline"]["signatures"].size() == 4)
    check("clean log passes", op.evaluate("all good\n", {"errors": 0, "warnings": 0})["issues"].is_empty())
    check("missing baseline rejected", op.run("res://demo/ci/logs/run.log", {"baseline": "res://nope.json"})["issues"][0]["kind"] == "bad_input")
    check("missing input is reported", op.run("res://definitely_missing.log", {"baseline": "res://demo/ci/logs/baseline.json"})["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/ci/logs/run.log", {"baseline": "res://demo/ci/logs/baseline.json"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Log Warning Budget Gate TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
