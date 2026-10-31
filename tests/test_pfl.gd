extends SceneTree
const Core := preload("res://addons/lifecycle/core/pfl_tester.gd")
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
    var result: Dictionary = op.run("res://demo/lifecycle")
    check("pause menu freezes itself", op._count(result, "pause_menu_frozen") == 1 and _has(result, "pause_menu_frozen", 15))
    check("always-on spinner noted", op._count(result, "keeps_running_when_paused") == 1 and _has(result, "keeps_running_when_paused", 11))
    check("paused player is fine", not _has(result, "keeps_running_when_paused", 8))
    check("no focus handling", op._count(result, "no_focus_pause") == 1)
    check("wall-clock timer found", op._count(result, "wallclock_timing") == 1)
    var nodes := {".": {"mode": 2, "parent": ""}, "A": {"mode": 0, "parent": "."}, "A/B": {"mode": 0, "parent": "A"}}
    check("inherit resolves through parents", op.effective_mode(nodes, "A/B") == 2)
    check("missing input is reported", op.run("res://definitely_missing_dir_pfl")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/lifecycle")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Pause, Focus, and Lifecycle Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
