extends SceneTree
const Core := preload("res://addons/wave_budget/core/wsb_planner.gd")
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
    var result: Dictionary = op.run("res://demo/balance/waves.json")
    var w2: Dictionary = result["waves"][1]
    check("wave 2 peak alive over budget", w2["peak_alive"] > 30 and op._count(result, "alive_budget") == 1)
    check("grunt burst plus brute exceeds spawn rate", w2["peak_spawns_per_second"] == 6 and op._count(result, "spawn_rate_budget") == 1)
    check("wave 3 overruns its duration", op._count(result, "wave_overrun") == 1)
    check("swarmling lifetime unknown", op._count(result, "unknown_enemy") == 1)
    check("wave 1 within budget", result["waves"][0]["peak_alive"] == 4)
    check("budgets configurable", op.run("res://demo/balance/waves.json", {"max_alive": 100, "max_spawn_rate": 10})["issues"].filter(func(i): return i["kind"] in ["alive_budget", "spawn_rate_budget"]).is_empty())
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/waves.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Wave Spawner Budget Planner TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
