extends SceneTree
const Core := preload("res://addons/scene_smoke/core/sst_smoke.gd")
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
    var result: Dictionary = op.run("res://demo/ci/smoke")
    check("three scenes, all load", result["summary"]["scenes"] == 3 and result["summary"]["loaded"] == 3)
    check("Godot 3 KinematicBody2D reported", op._count(result, "unknown_type") == 1 and result["issues"].any(func(i): return i["message"].contains("KinematicBody2D")))
    check("deleted texture dependency reported", op._count(result, "missing_dependency") == 1)
    check("clean scene has no findings", not result["issues"].any(func(i): return i["path"].ends_with("ok.tscn")))
    check("non-scene load reported", op.check_scene("res://demo/ci/logs/run.log").any(func(i): return i["kind"] == "load_failed"))
    check("missing input is reported", op.run("res://definitely_missing_dir_sst")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/ci/smoke")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Scene Load Smoke Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
