## Input Matrix and Rebinding tests.
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

const Matrix := preload("res://addons/input_matrix/core/imx_matrix.gd")


func _init() -> void:
    var op = Matrix.new()
    var key := InputEventKey.new()
    key.physical_keycode = KEY_SPACE
    _check("key event classifies as keyboard Space", op.classify_event(key) == {"device": "keyboard", "id": "Space"}, str(op.classify_event(key)))
    var pad := InputEventJoypadButton.new()
    pad.button_index = JOY_BUTTON_A
    _check("pad button classifies as joypad", str(op.classify_event(pad)["device"]) == "joypad")
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    _check("mouse button classifies as mouse", str(op.classify_event(mouse)["device"]) == "mouse" and str(op.classify_event(mouse)["id"]) == "button_1")
    var actions = JSON.parse_string(FileAccess.get_file_as_string("res://demo/input/actions.json"))
    var r: Dictionary = op.run(actions)
    _check("space bound to jump and dash collides (gate kind)", _kinds(r["issues"]).has("binding_collision"), str(r["issues"]))
    _check("fire has no gamepad binding", _kinds(r["issues"]).has("no_gamepad"))
    _check("matrix covers all four fixture actions", (r["matrix"] as Dictionary).size() == 4)
    var menu: Array = r["remap_menu"]
    _check("remap menu is sorted and display-named", str((menu[0] as Dictionary)["action"]) == "dash" and str((menu[0] as Dictionary)["display"]) == "Dash", str(menu[0]))
    var clean: Dictionary = op.run({"jump": [{"device": "keyboard", "id": "Space"}, {"device": "joypad", "id": "button_0"}]})
    _check("a clean single action has no issues", (clean["issues"] as Array).is_empty(), str(clean["issues"]))
    _check("to_markdown renders the matrix table", op.to_markdown(r).contains("| jump |"))
    _finish("Input Matrix and Rebinding TESTS")
