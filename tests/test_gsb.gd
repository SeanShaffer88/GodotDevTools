extends SceneTree
const Core := preload("res://addons/scenario_tests/core/gsb_scenario.gd")
const Runner := preload("res://addons/scenario_tests/runtime/gsb_runner.gd")
var op = Core.new()
var passed := 0
var failed := 0
var runner
var frames := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _init() -> void:
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://demo/testing/scenario/hold_and_add.json"))
    check("scenario validates", op.validate(data).is_empty())
    check("bad step rejected", op.validate({"scene": data["scene"], "steps": [{"jump": 1}]}).size() == 1)
    check("missing scene rejected", op.validate({"scene": "res://nope.tscn", "steps": [{"frames": 1}]}).size() == 1)
    check("compare ops", op.compare(5, ">=", 5) and not op.compare(1, "==", 2) and op.compare(1.0004, "approx", 1) and op.compare("hello", "contains", "ell"))
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    runner = Runner.new()
    root.add_child(runner)
    runner.start(data)
    process_frame.connect(_poll)

func _poll() -> void:
    frames += 1
    if not runner.done and frames < 2000:
        return
    process_frame.disconnect(_poll)
    var result: Dictionary = op.evaluate(runner.results, "scenario")
    check("runner finished", runner.done)
    check("three assertions evaluated", result["summary"]["checks"] == 3)
    check("held input counted over physics frames", result["results"][0]["ok"])
    check("call step applied", result["results"][1]["ok"])
    check("deliberately wrong assertion fails", not result["results"][2]["ok"] and op._count(result, "assertion_failed") == 1)
    check("input released afterwards", not Input.is_action_pressed("ui_accept"))
    check("markdown renders", op.to_markdown(result).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(result)) is Dictionary)
    print("Gameplay Scenario Test Builder TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
