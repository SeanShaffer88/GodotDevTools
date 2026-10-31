## Camera Orchestrator tests.
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

const Motion := preload("res://addons/camera_orch/core/cor_motion.gd")


func _init() -> void:
    var op = Motion.new()
    _check("seeded value noise is deterministic", op.seeded_value(7, 3) == op.seeded_value(7, 3))
    _check("seeded value noise stays in range", absf(op.seeded_value(99, 5)) <= 1.0)
    var shake := {"amplitude": 10.0, "frequency": 28.0, "duration": 0.35, "seed": 7}
    var a: Vector2 = op.shake_sample(shake, 0.05)
    var b: Vector2 = op.shake_sample(shake, 0.05)
    _check("same seed replays the same shake", a == b and a != Vector2.ZERO)
    _check("shake is over after its duration", op.shake_sample(shake, 1.0) == Vector2.ZERO)
    _check("linear ease is halfway at halfway", absf(op.ease_value("linear", 0.5) - 0.5) < 0.0001)
    _check("in-quad ease is a quarter at halfway", absf(op.ease_value("in_quad", 0.5) - 0.25) < 0.0001)
    var zoom := {"from": 1.0, "to": 0.6, "duration": 0.8, "ease": "in_out_cubic"}
    _check("transition lands on its target", absf(op.transition_sample(zoom, 0.8) - 0.6) < 0.0001, str(op.transition_sample(zoom, 0.8)))
    _check("target inside the deadzone does not move the camera", op.framing_position(Vector2.ZERO, Vector2(30, 10), Vector2(120, 80)) == Vector2.ZERO)
    var pushed: Vector2 = op.framing_position(Vector2.ZERO, Vector2(100, 0), Vector2(120, 80))
    _check("target past the deadzone drags the camera to the edge", absf(pushed.x - 40.0) < 0.0001 and absf(pushed.y) < 0.0001, str(pushed))
    var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://demo/camera/shake_config.json"))
    var r: Dictionary = op.run(cfg)
    _check("unknown ease in the fixture is flagged (gate kind)", _kinds(r["issues"]).has("config_error"), str(r["issues"]))
    _check("preview samples generated for both shakes", (((r["previews"] as Dictionary).get("shake:impact", [])) as Array).size() == 40, str((r["previews"] as Dictionary).keys()))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Camera Orchestrator TESTS")
