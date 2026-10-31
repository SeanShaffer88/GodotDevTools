extends SceneTree
const Core := preload("res://addons/store_assets/core/sav_validator.gd")
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
    var result: Dictionary = op.run("res://demo/shipping/store/profile.json")
    check("three images checked", result["summary"]["images_checked"] == 3)
    check("icon and one screenshot wrong size", op._count(result, "wrong_size") == 2)
    check("too few screenshots", op._count(result, "count_out_of_range") == 1)
    check("missing header reported", op._count(result, "missing_asset") == 1)
    check("JPEG size read from SOF", op.image_size(FileAccess.get_file_as_bytes("res://demo/shipping/store/screens/shot1.jpg")) == [1920, 1080])
    check("PNG size read from IHDR", op.image_size(FileAccess.get_file_as_bytes("res://demo/shipping/store/icon.png")) == [256, 256])
    check("entry without path rejected", op.evaluate({"assets": [{"id": "x"}]}, {})["issues"][0]["kind"] == "bad_profile")
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_profile")
    var r: Dictionary = op.run("res://demo/shipping/store/profile.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Store Asset Validator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
