extends SceneTree
const Core := preload("res://addons/colorvision/core/cvp_previewer.gd")
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
    var result: Dictionary = op.run("res://demo/glyphs/palette_cvd.json")
    check("ten pairs compared", result["summary"]["pairs"] == 10)
    check("health and danger merge under deuteranopia", result["issues"].any(func(i): return i["message"].begins_with("health and danger") and i["message"].contains("deuteranopia")))
    check("three pair/simulation problems", op._count(result, "indistinct_under_cvd") == 3)
    check("no pairs close in normal vision", op._count(result, "indistinct_normal") == 0)
    check("white unchanged by simulation", result["preview"]["text"]["deuteranopia"] == "ffffff" or result["preview"]["text"]["deuteranopia"] == "#ffffff")
    check("close normal pair reported once", op._count(op.evaluate({"colors": {"a": "#808080", "b": "#828282"}}), "indistinct_normal") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/glyphs/palette_cvd.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Color-Vision and Contrast Previewer TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
