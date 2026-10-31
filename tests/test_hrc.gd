extends SceneTree
const Core := preload("res://addons/handheld_readiness/core/hrc_checker.gd")
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
    var o := {"project": "res://demo/shipping/handheld/project_handheld.godot"}
    var result: Dictionary = op.run("res://demo/shipping/handheld", o)
    check("stretch disabled reported", op._count(result, "stretch_disabled") == 1)
    check("mouse-only aim action reported", op._count(result, "no_gamepad_binding") == 1)
    check("14 px at 1080 becomes too small at 800", op._count(result, "small_text") == 1 and _has(result, "small_text", 6))
    check("unfocusable shop button reported", op._count(result, "not_focusable") == 1)
    check("scale factor computed", is_equal_approx(float(result["summary"]["scale_to_target"]), 0.741))
    var ok_proj := "[display]\nwindow/size/viewport_height=720\nwindow/stretch/mode=\"canvas_items\"\n"
    check("canvas_items stretch passes", op._count(op.analyze({}, {"project_text": ok_proj}), "stretch_disabled") == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir", {"project": "res://demo/shipping/handheld/project_handheld.godot"})["issues"][0]["kind"] == "scan_error")
    var r: Dictionary = op.run("res://demo/shipping/handheld", {"project": "res://demo/shipping/handheld/project_handheld.godot"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Handheld Readiness Checklist TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
