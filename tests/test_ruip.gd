## Responsive UI Previewer tests.
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

const Evaluator := preload("res://addons/responsive_ui/core/ruip_evaluator.gd")


func _init() -> void:
    var op = Evaluator.new()
    var expand: Rect2 = op.content_rect(Vector2(1152, 648), Vector2i(1920, 1080), "canvas_items", "expand")
    _check("expand fills the target", expand.size == Vector2(1920, 1080), str(expand))
    var keep: Rect2 = op.content_rect(Vector2(1152, 648), Vector2i(800, 600), "canvas_items", "keep")
    _check("keep fits width and letterboxes height", keep.size == Vector2(800, 450), str(keep))
    var disabled: Rect2 = op.content_rect(Vector2(1152, 648), Vector2i(800, 600), "disabled", "expand")
    _check("stretch disabled keeps base size", disabled.size == Vector2(1152, 648), str(disabled))
    var control := {"name": "WideBanner", "path": "res://demo/ui/hud.tscn", "rect": Rect2(0, 0, 2000, 40), "anchors_full": false}
    var phone: Dictionary = {"name": "Phone portrait (notch)", "size": Vector2i(390, 844), "safe": Rect2i(0, 47, 390, 763)}
    var issues: Array = op.evaluate_control(control, Vector2(1152, 648), phone, "canvas_items", "expand")
    _check("2000px banner breaks the phone safe area", _kinds(issues).has("outside_safe_area"), str(issues))
    var small := {"name": "Tiny", "path": "res://demo/ui/hud.tscn", "rect": Rect2(0, 0, 60, 20), "anchors_full": false}
    var issues2: Array = op.evaluate_control(small, Vector2(1152, 648), phone, "canvas_items", "expand")
    _check("shrunk control flagged as too small", _kinds(issues2).has("target_too_small"), str(issues2))
    var result: Dictionary = op.evaluate_project()
    _check("project evaluation covers the demo scenes", int(result["summary"]["scenes"]) >= 4, str(result["summary"]))
    _check("project evaluation uses project stretch (expand)", str(result["summary"]["aspect"]) == "expand")
    _check("fixture HUD overflows somewhere", _kinds(result["issues"]).has("outside_safe_area"))
    _finish("RUIP TESTS")
