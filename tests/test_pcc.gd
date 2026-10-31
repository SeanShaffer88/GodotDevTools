extends SceneTree
const Core := preload("res://addons/palette_check/core/pcc_checker.gd")
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
    var result: Dictionary = op.run("res://demo/rendering", {"palette": "res://demo/rendering/palette.json"})
    check("accent cyan off palette", _has(result, "off_palette", 12))
    check("exact palette colours pass", not _has(result, "off_palette", 9) and not _has(result, "off_palette", 15))
    check("theme resource colour checked", not result["issues"].any(func(i): return i["path"].ends_with("ui_theme.tres")))
    check("one off-palette colour in fixture", op._count(result, "off_palette") == 1)
    check("white Lab is (100, 0, 0)", op.lab(Color.WHITE).distance_to(Vector3(100, 0, 0)) < 0.05)
    check("missing palette rejected", op.run("res://demo/rendering", {"palette": "res://nope.json"})["issues"][0]["kind"] == "bad_palette")
    check("transparent and ignored colours skipped", op.analyze({"res://a.tscn": "c = Color(1, 0, 0, 0)\nd = Color(1, 1, 1, 1)\n"}, {"palette_data": {"colors": ["#000000"], "ignore": ["#ffffff"]}})["summary"]["colours_checked"] == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir", {"palette": "res://demo/rendering/palette.json"})["issues"][0]["kind"] == "scan_error")
    var r: Dictionary = op.run("res://demo/rendering", {"palette": "res://demo/rendering/palette.json"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Colour Palette Consistency Checker TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
