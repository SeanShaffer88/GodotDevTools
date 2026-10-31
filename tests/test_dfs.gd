extends SceneTree
const Core := preload("res://addons/damage_sandbox/core/dfs_sandbox.gd")
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
    var result: Dictionary = op.run("res://demo/balance/damage.json")
    check("all 54 combinations evaluated", result["summary"]["combinations"] == 54)
    check("armor subtraction goes negative", op._count(result, "negative_result") == 1)
    check("no overflow under 1000", op._count(result, "overflow") == 0)
    check("monotonic in atk and def", op._count(result, "non_monotonic") == 0)
    check("range reported", is_equal_approx(float(result["summary"]["max"]), 400.0))
    var nm: Dictionary = op.evaluate({"formula": "x * (10 - x)", "vars": {"x": [1, 5, 9]}, "expect": {"monotonic": {"x": "increasing"}}})
    check("non-monotonic formula caught", op._count(nm, "non_monotonic") == 1)
    check("division by zero reported", op._count(op.evaluate({"formula": "1.0 / d", "vars": {"d": [0.0, 1.0]}}), "eval_error") == 1)
    check("parse error reported", op.evaluate({"formula": "atk *", "vars": {"atk": [1]}})["issues"][0]["kind"] == "eval_error")
    check("combination cap enforced", op.run("res://demo/balance/damage.json", {"max_combinations": 10})["issues"][0]["kind"] == "bad_input")
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/damage.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Damage Formula Sandbox TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
