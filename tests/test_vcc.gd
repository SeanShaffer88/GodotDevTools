extends SceneTree
const Core := preload("res://addons/version_consistency/core/vcc_checker.gd")
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
    var result: Dictionary = op.run("res://demo/shipping/version_project.godot", {"presets": "res://demo/shipping/android_presets.cfg"})
    check("project version read", result["summary"]["expected"] == "1.2.0")
    check("three preset versions compared", result["summary"]["compared"] == 3)
    check("windows product version mismatch only", op._count(result, "version_mismatch") == 1 and result["issues"][0]["message"].contains("product_version"))
    check("trailing zeros ignored", op._norm("1.2.0.0") == op._norm("1.2"))
    check("android code reported", result["android_version_codes"]["Android"] == "7")
    check("expected override", op._count(op.run("res://demo/shipping/version_project.godot", {"presets": "res://demo/shipping/android_presets.cfg", "expected": "1.1.9"}), "version_mismatch") == 2)
    check("missing input is reported", op.run("res://definitely_missing.godot")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/shipping/version_project.godot", {"presets": "res://demo/shipping/android_presets.cfg"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Version Consistency Checker TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
