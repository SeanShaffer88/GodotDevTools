extends SceneTree
const Core := preload("res://addons/difficulty_curve/core/dca_analyzer.gd")
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
    var result: Dictionary = op.run("res://demo/balance/difficulty.json")
    check("six levels read", result["summary"]["levels"] == 6)
    check("level 4 spike flagged", op._count(result, "difficulty_spike") == 1 and result["issues"].any(func(i): return i["kind"] == "difficulty_spike" and i["message"].begins_with("Level 4")))
    check("two dips flagged", op._count(result, "difficulty_dip") == 2)
    check("nothing too hard at default ceiling", op._count(result, "too_hard") == 0)
    check("lower ceiling catches level 4", op._count(op.run("res://demo/balance/difficulty.json", {"max_ratio": 1.2}), "too_hard") == 1)
    check("unsorted levels reported", op._count(op.evaluate({"levels": [{"level": 2, "enemy_power": 1, "player_power": 1}, {"level": 1, "enemy_power": 1, "player_power": 1}]}), "level_order") == 1)
    check("zero player power rejected", op.evaluate({"levels": [{"level": 1, "enemy_power": 1, "player_power": 0}]})["issues"][0]["kind"] == "bad_input")
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/difficulty.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Difficulty Curve Analyzer TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
