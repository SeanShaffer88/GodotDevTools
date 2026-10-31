extends SceneTree
const Core := preload("res://addons/controller_glyphs/core/cgp_validator.gd")
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
    var o := {"project": "res://demo/ci/input_actions.godot"}
    var result: Dictionary = op.run("res://demo/glyphs", o)
    check("five prompted actions on two devices", result["summary"]["actions_prompted"] == 5 and result["summary"]["devices"] == 2)
    check("roll is not an action", op._count(result, "unknown_action") == 1)
    check("move_left lacks a keyboard glyph", op._count(result, "missing_glyph") == 1)
    check("gamepad prompts without joypad bindings", op._count(result, "unbound_for_device") == 5)
    check("bindings classified", op.bindings(FileAccess.get_file_as_string("res://demo/ci/input_actions.godot"))["fire"]["keyboard"])
    check("custom token pattern", op.analyze({"res://a.csv": "Press {jump}"}, {"token": "\\{([a-z_]+)\\}", "glyph_index": {}, "project_text": "[input]\njump={\n\"events\": []\n}\n"})["summary"]["actions_prompted"] == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir")["issues"][0]["kind"] == "scan_error")
    var r: Dictionary = op.run("res://demo/glyphs", {"project": "res://demo/ci/input_actions.godot"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Controller Glyph and Prompt Validator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
