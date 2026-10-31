extends SceneTree
const Core := preload("res://addons/xp_curve/core/xpc_planner.gd")
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
    var result: Dictionary = op.run("res://demo/balance/xp.json")
    check("seven levels planned", result["summary"]["levels"] == 7)
    check("rate bands applied", is_equal_approx(result["curve"][3]["minutes"], 3.75))
    check("level 5 wall flagged", op._count(result, "level_wall") == 1 and result["issues"].any(func(i): return i["message"].begins_with("Level 5")))
    check("shrinking requirement noted", op._count(result, "xp_not_increasing") == 1)
    check("total time summed", is_equal_approx(result["summary"]["total_hours"], 0.96))
    var f: Dictionary = op.evaluate({"formula": "100 * pow(level, 1.5)", "max_level": 4, "xp_per_minute": [{"from_level": 1, "rate": 100}]})
    check("formula curve generated", f["summary"]["levels"] == 3)
    check("missing rate reported", op._count(op.evaluate({"xp_to_next": [10, 10], "xp_per_minute": [{"from_level": 2, "rate": 5}]}), "no_rate") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/xp.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("XP Curve Planner TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
