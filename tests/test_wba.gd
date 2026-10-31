extends SceneTree
const Core := preload("res://addons/world_bounds/core/wba_auditor.gd")
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
    var result: Dictionary = op.run("res://demo/gameplay/arena.tscn")
    check("two solid shapes", result["summary"]["solids"] == 2)
    check("no kill floor below the arena", op._count(result, "missing_kill_floor") == 1)
    check("both sides open", op._count(result, "open_side") == 2)
    var with_kill := FileAccess.get_file_as_string("res://demo/gameplay/arena.tscn") + "\n[sub_resource type=\"RectangleShape2D\" id=\"K\"]\nsize = Vector2(2000, 50)\n[node name=\"KillFloor\" type=\"Area2D\" parent=\".\"]\nposition = Vector2(550, 500)\n[node name=\"Shape\" type=\"CollisionShape2D\" parent=\"KillFloor\"]\nshape = SubResource(\"K\")\n"
    check("kill floor below satisfies the check", op._count(op.evaluate(op.parse_2d(with_kill)), "missing_kill_floor") == 0)
    var bad_kill := FileAccess.get_file_as_string("res://demo/gameplay/arena.tscn") + "\n[sub_resource type=\"RectangleShape2D\" id=\"K2\"]\nsize = Vector2(100, 40)\n[node name=\"KillZone\" type=\"Area2D\" parent=\".\"]\nposition = Vector2(550, 300)\n[node name=\"Shape\" type=\"CollisionShape2D\" parent=\"KillZone\"]\nshape = SubResource(\"K2\")\n"
    check("kill zone on the floor surface flagged", op._count(op.evaluate(op.parse_2d(bad_kill)), "kill_zone_overlap") == 1)
    check("missing input is reported", op.run("res://definitely_missing.tscn")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/gameplay/arena.tscn")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("World Boundary and Out-of-Bounds Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
