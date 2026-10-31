extends SceneTree
const Core := preload("res://addons/spawn_validator/core/spv_validator.gd")
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
    var result: Dictionary = op.run("res://demo/gameplay/arena.tscn", {"nav": "res://demo/gameplay/nav.tres"})
    check("four spawns found by group", result["summary"]["spawns"] == 4)
    check("spawn inside the pillar", op._count(result, "blocked_spawn") == 1 and _has(result, "blocked_spawn", 26))
    check("two spawns too close", op._count(result, "crowded_spawns") == 1)
    check("all spawns on the navmesh", op._count(result, "off_nav_spawn") == 0)
    check("spacing configurable", op._count(op.run("res://demo/gameplay/arena.tscn", {"min_spacing": 2.0}), "crowded_spawns") == 0)
    check("nested positions accumulate", op.parse_2d("[node name=\"R\" type=\"Node2D\"]\nposition = Vector2(10, 0)\n[node name=\"A\" type=\"Node2D\" parent=\".\"]\nposition = Vector2(5, 5)\n[node name=\"B\" type=\"Marker2D\" parent=\"A\"]\nposition = Vector2(1, 1)\n")["nodes"][2]["pos"] == Vector2(16, 6))
    check("missing input is reported", op.run("res://definitely_missing.tscn")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/gameplay/arena.tscn", {"nav": "res://demo/gameplay/nav.tres"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Spawn Point and Encounter Validator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
