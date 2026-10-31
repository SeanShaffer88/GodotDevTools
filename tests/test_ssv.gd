extends SceneTree
const Core := preload("res://addons/settings_validator/core/ssv_validator.gd")
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
    var result: Dictionary = op.run("res://demo/shipping/settings")
    check("one sample file validated", result["summary"]["files"] == 1)
    check("volume 1.4 out of range", op._count(result, "out_of_range") == 1)
    check("fullscreen string is wrong type", op._count(result, "wrong_type") == 1)
    check("1600x900 not allowed", op._count(result, "invalid_enum") == 1)
    check("legacy key unknown", op._count(result, "unknown_key") == 1)
    check("JSON settings flattened", op.flatten("a.json", "{\"audio\": {\"master_volume\": 0.5}}")["audio/master_volume"] == 0.5)
    check("missing schema rejected", op.run("res://demo/shipping/settings", {"schema": "res://nope.json"})["issues"][0]["kind"] == "bad_schema")
    check("missing input is reported", op.run("res://definitely_missing_dir", {"schema": "res://demo/shipping/settings/schema.json"})["issues"][0]["kind"] == "scan_error")
    var r: Dictionary = op.run("res://demo/shipping/settings")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Settings File Validator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
