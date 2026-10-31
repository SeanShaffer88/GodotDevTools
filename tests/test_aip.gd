extends SceneTree
const Core := preload("res://addons/ai_perception/core/aip_debugger.gd")
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
    var result: Dictionary = op.run("res://demo/gameplay/perception.json")
    check("four agent-target pairs traced", result["summary"]["pairs"] == 4)
    check("wall hides the player", not result["trace"]["guard>player_hidden"]["sees"] and result["trace"]["guard>player_hidden"]["walls_crossed"] == 1)
    check("open player seen inside the cone", result["trace"]["guard>player_open"]["sees"])
    check("sentry out of range fails its expectation", op._count(result, "expectation_failed") == 1 and result["issues"][0]["message"].begins_with("sentry>player_open"))
    check("reasons recorded", result["trace"]["sentry>player_open"]["why"][0].contains("> sight range"))
    var muffled: Dictionary = op.evaluate({"walls": [[5, -5, 5, 5]], "agents": [{"id": "a", "pos": [0, 0], "hearing_range": 15}], "targets": [{"id": "t", "pos": [10, 0], "noise": 1.0}]}, {"wall_muffle": 0.5})
    check("walls muffle hearing", not muffled["trace"]["a>t"]["hears"])
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/gameplay/perception.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("AI Perception Debugger TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
