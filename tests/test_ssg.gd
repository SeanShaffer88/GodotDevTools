extends SceneTree
const Core := preload("res://addons/scene_snapshot/core/ssg_snapshot.gd")
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
    var result: Dictionary = op.run("res://demo/workflow/snapshot/level_v2.tscn", {"compare": "res://demo/workflow/snapshot/level_v1.tscn"})
    check("coin added", op._count(result, "node_added") == 1)
    check("old lamp removed", op._count(result, "node_removed") == 1)
    check("player script dropped", op._count(result, "script_changed") == 1)
    check("player moved", result["issues"].any(func(i): return i["kind"] == "property_changed" and i["message"].begins_with("Player.position")))
    check("ext_resource ids resolved to paths", op.snapshot(FileAccess.get_file_as_string("res://demo/workflow/snapshot/level_v1.tscn"))["nodes"]["Player"]["script"] == "res://demo/code_health/player.gd")
    var snap_json: String = result["artifacts"]["snapshot.json"]
    check("snapshot round-trips as a comparison", op.evaluate(op.snapshot(FileAccess.get_file_as_string("res://demo/workflow/snapshot/level_v2.tscn")), JSON.parse_string(snap_json))["issues"].is_empty())
    check("missing input is reported", op.run("res://definitely_missing.tscn")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/workflow/snapshot/level_v2.tscn", {"compare": "res://demo/workflow/snapshot/level_v1.tscn"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Scene Review Snapshot Generator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
