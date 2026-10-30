## Accessibility Checker tests.
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

const Checker := preload("res://addons/accessibility/core/a11y_checker.gd")


func _init() -> void:
    _check("contrast black on white is about 21:1", Checker.contrast_ratio(Color.BLACK, Color.WHITE) > 15.0,
        str(Checker.contrast_ratio(Color.BLACK, Color.WHITE)))
    _check("contrast of a colour with itself is 1:1", absf(Checker.contrast_ratio(Color(0.4, 0.4, 0.4), Color(0.4, 0.4, 0.4)) - 1.0) < 0.01)
    _check("contrast mid grey on dark is low", Checker.contrast_ratio(Color(0.2, 0.2, 0.22), Color(0.08, 0.08, 0.1)) < 4.5)
    var op = Checker.new()
    var r: Dictionary = op.scan()
    var kinds := _kinds(r["issues"])
    _check("scan covers the demo scenes", int(r["summary"]["scenes"]) >= 4, str(r["summary"]))
    _check("tiny text flagged (9px label)", kinds.has("tiny_text"), str(kinds))
    _check("low contrast flagged (dim label)", kinds.has("low_contrast"))
    _check("keyboard focus flagged (focus_mode=0 button)", kinds.has("no_keyboard_focus"))
    _check("colour-only indicator noted (StatusIndicator)", kinds.has("color_only_check"))
    _finish("A11Y TESTS")
