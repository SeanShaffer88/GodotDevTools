extends SceneTree
const Core := preload("res://addons/texture_filter/core/tfc_checker.gd")
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
    var result: Dictionary = op.run("res://demo/assets_audit")
    check("one pixel texture found", result["summary"]["pixel_textures"] == 1)
    check("mipmaps on pixel art flagged", op._count(result, "pixel_mipmaps") == 1)
    check("lossy pixel art flagged", op._count(result, "pixel_lossy") == 1)
    check("linear default reported", op._count(result, "filter_default_linear") == 1)
    var nearest: Dictionary = op.analyze({"res://pixel/a.png.import": "importer=\"texture\"\n[params]\ncompress/mode=0\nmipmaps/generate=false\n"}, {"project_text": "[rendering]\ntextures/canvas_textures/default_texture_filter=0\n"})
    check("clean pixel setup passes", nearest["issues"].is_empty())
    check("non-pixel paths ignored", op.analyze({"res://art/a.png.import": "importer=\"texture\"\nmipmaps/generate=true\n"})["summary"]["pixel_textures"] == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir_tfc")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/assets_audit")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Texture Filter Consistency Checker TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
