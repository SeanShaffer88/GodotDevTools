extends SceneTree
const Core := preload("res://addons/loot_sim/core/lts_simulator.gd")
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
    var result: Dictionary = op.run("res://demo/balance/loot.json")
    var chest: Dictionary = result["tables"]["chest"]
    check("expected value per chest open", is_equal_approx(chest["expected_value_per_open"], 19.43))
    check("dragon blade drought flagged", op._count(result, "drought_risk") == 1)
    check("zero-weight key flagged", op._count(result, "zero_weight") == 1)
    var boss: Dictionary = result["tables"]["boss"]
    check("three rolls raise per-open odds", is_equal_approx(boss["items"][0]["per_open"], 0.57813))
    var again: Dictionary = op.run("res://demo/balance/loot.json")
    check("same seed, same simulation", again["tables"]["chest"]["items"][2]["longest_drought_seen"] == chest["items"][2]["longest_drought_seen"])
    var gold: Dictionary = chest["items"][0]
    check("observed rate near analytic rate", absf(float(gold["observed_per_open"]) - float(gold["per_open"])) < 0.02)
    check("empty table is an error", op.evaluate({"tables": {"x": {"entries": []}}})["issues"][0]["kind"] == "empty_table")
    check("threshold configurable", op._count(op.run("res://demo/balance/loot.json", {"max_drought": 5000}), "drought_risk") == 0)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/loot.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Loot Table and Economy Simulator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
