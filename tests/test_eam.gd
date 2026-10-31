extends SceneTree
const Core := preload("res://addons/macro_recorder/core/eam_macro.gd")
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
    var result: Dictionary = op.run("res://demo/macros/center_labels.json", {"scene": "res://demo/workflow/drift/menu.tscn"})
    check("two changes planned", result["summary"]["changes"] == 2)
    check("only the off-centre label changes alignment", result["issues"].any(func(i): return i["message"].begins_with("Label4.horizontal_alignment")))
    check("title font size raised", result["issues"].any(func(i): return i["message"].begins_with("Label0.theme_override_font_sizes/font_size: 20 -> 32")))
    check("missing node step reported", op._count(result, "step_unmatched") == 1)
    check("preview did not modify the scene", FileAccess.get_file_as_string("res://demo/workflow/drift/menu.tscn").contains("horizontal_alignment = 2"))
    DirAccess.copy_absolute(ProjectSettings.globalize_path("res://demo/workflow/drift/menu.tscn"), ProjectSettings.globalize_path("user://gdt_macro_menu.tscn"))
    var applied: Dictionary = op.run("res://demo/macros/center_labels.json", {"scene": "user://gdt_macro_menu.tscn", "apply": true})
    check("apply writes the copy", applied["summary"]["applied"] and not FileAccess.get_file_as_string("user://gdt_macro_menu.tscn").contains("horizontal_alignment = 2"))
    check("recorded vectors survive JSON", op._value(JSON.parse_string(JSON.stringify(op.to_json_step({"node": ".", "property": "position", "value": Vector2(3, 4)})["value"]))) == Vector2(3, 4))
    check("object values in a macro are refused", op._value({"var": "Object(Node,\"name\":\"x\")"}) == null)
    check("malformed step rejected", op.validate({"steps": [{"property": "x"}]})[0]["kind"] == "bad_macro")
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_macro")
    var r: Dictionary = op.run("res://demo/macros/center_labels.json", {"scene": "res://demo/workflow/drift/menu.tscn"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Editor Action Macro Recorder TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
