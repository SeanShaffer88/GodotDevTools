extends SceneTree
const Core := preload("res://addons/achievements/core/ach_checker.gd")
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
    var result: Dictionary = op.run("res://demo/balance/achievements.json")
    check("two of seven reachable", result["summary"]["reachable"] == 2)
    check("unknown double_jump event", op._count(result, "unknown_event") == 1)
    check("tycoon above coin cap", op._count(result, "unreachable_threshold") == 1)
    check("unknown speedster reference", op._count(result, "unknown_achievement") == 1)
    check("loop reported once", op._count(result, "achievement_cycle") == 1)
    check("completionist blocked only by missing deps", op._count(result, "blocked_achievement") == 0)
    var meta: Dictionary = op.evaluate({"events": [], "stats": {"x": 5}, "achievements": [{"id": "a", "requires": {"stat": "x", "gte": 9}}, {"id": "b", "requires": {"all": ["a"]}}]})
    check("meta achievement blocked by unreachable dependency", op._count(meta, "blocked_achievement") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/achievements.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Achievement Reachability Checker TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
