extends SceneTree
const Core := preload("res://addons/physics_jitter/core/pjt_detector.gd")
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
    var o := {"project": "res://demo/runtime_perf/physics_project.godot"}
    var result: Dictionary = op.run("res://demo/runtime_perf", o)
    check("small bullet without CCD at risk", op._count(result, "tunneling_risk") == 1)
    check("rigid body moved by position in _process", op._count(result, "transform_fight") == 1 and _has(result, "transform_fight", 5))
    check("move_and_slide in _process flagged", op._count(result, "physics_in_process") == 1)
    check("30 Hz ticks flagged", op._count(result, "low_tick_rate") == 1)
    check("_integrate_forces exempt", op._count(op.analyze({"res://a.gd": "extends RigidBody2D\nfunc _integrate_forces(s):\n\ttransform = Transform2D()\n"}), "transform_fight") == 0)
    var ccd := "[sub_resource type=\"CircleShape2D\" id=\"c\"]\nradius = 1.0\n[node name=\"B\" type=\"RigidBody2D\"]\ncontinuous_cd = 2\n[node name=\"S\" type=\"CollisionShape2D\" parent=\".\"]\nshape = SubResource(\"c\")\n"
    check("CCD enabled body is fine", op._count(op.analyze({"res://b.tscn": ccd}), "tunneling_risk") == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir")["issues"][0]["kind"] == "scan_error")
    var r: Dictionary = op.run("res://demo/runtime_perf", {"project": "res://demo/runtime_perf/physics_project.godot"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Physics Jitter and Tunneling Detector TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
