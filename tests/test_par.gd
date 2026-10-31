## Procedural Animation Solvers tests.
extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0


func _check(label: String, ok: bool, evidence: String = "") -> void:
    if ok:
        _passes += 1
        print("PASS  ", label)
    else:
        _failures.append(label)
        print("FAIL  ", label, "  ", evidence)


func _finish(name: String) -> void:
    print("----")
    print(name, ": %d passed, %d failed" % [_passes, _failures.size()])
    quit(1 if not _failures.is_empty() else 0)


func _kinds(issues: Array) -> Array:
    var out: Array = []
    for i in issues:
        out.append(i["kind"])
    return out

const Solvers := preload("res://addons/proc_anim/core/par_solvers.gd")


func _init() -> void:
    var op = Solvers.new()
    var leg: Dictionary = op.solve_two_bone(Vector2.ZERO, Vector2(30, 20), 25, 25, 1)
    _check("two-bone IK reaches a reachable target", bool(leg["reachable"]) and float(leg["error"]) < 0.01, str(leg))
    var far: Dictionary = op.solve_two_bone(Vector2.ZERO, Vector2(300, 0), 50, 50, 1)
    _check("two-bone IK clamps an unreachable target", not bool(far["reachable"]) and absf(float(far["error"]) - 200.0) < 0.01, str(far))
    var arm: Dictionary = op.fabrik([Vector2(0, -40), Vector2(10, -30), Vector2(20, -20)], Vector2(20, -25), 16, 0.5)
    _check("FABRIK converges on a reachable target", bool(arm["converged"]) and float(arm["error"]) <= 0.5, str(arm))
    _check("look-at angle to +x is zero", absf(op.look_at_angle(Vector2.ZERO, Vector2(1, 0))) < 0.0001)
    var keys: Array = op.squash_stretch(30.0, 0.01, 8.0, 12, true)
    var volume_ok := true
    for k in keys:
        var sc: Vector2 = k["scale"]
        if absf(sc.x * sc.y - 1.0) > 0.000001:
            volume_ok = false
    _check("squash and stretch preserves volume", volume_ok and keys.size() == 12)
    var foot: Dictionary = op.foot_placement(Vector2(5, 0), 20.0, [{"x": 0, "y": 10}, {"x": 10, "y": 10}])
    _check("foot probe finds the ground", bool(foot["grounded"]) and absf((foot["contact"] as Vector2).y - 10.0) < 0.0001, str(foot))
    var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://demo/anim/rig_config.json"))
    var r: Dictionary = op.run(cfg)
    _check("fixture config: four chains solve", int(r["summary"]["solved"]) == 4, str(r["summary"]))
    _check("fixture config: unreachable tail flagged (gate kind)", _kinds(r["issues"]).has("solver_error") and int(r["summary"]["issues"]) == 1, str(r["issues"]))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Procedural Animation Solvers TESTS")
