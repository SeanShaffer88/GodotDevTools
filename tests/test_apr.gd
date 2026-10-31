extends SceneTree
const Core := preload("res://addons/android_permissions/core/apr_reviewer.gd")
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
    var result: Dictionary = op.run("res://demo/shipping/android_presets.cfg", {"justifications": "res://demo/shipping/justifications.json"})
    check("one Android preset with five permissions", result["permissions"]["Android"].size() == 5)
    check("custom permission kept verbatim", "com.example.permission.PUSH" in result["permissions"]["Android"])
    check("camera and fine location flagged", op._count(result, "sensitive_permission") == 2)
    check("three permissions lack justification", op._count(result, "unjustified_permission") == 3)
    check("false permissions ignored", not ("RECORD_AUDIO" in result["permissions"]["Android"]))
    check("no justification file, no unjustified findings", op._count(op.run("res://demo/shipping/android_presets.cfg"), "unjustified_permission") == 0)
    check("non-Android presets ignored", op.evaluate("[preset.0]\nname=\"PC\"\nplatform=\"Windows Desktop\"\n")["issues"][0]["kind"] == "no_android_preset")
    check("missing input is reported", op.run("res://definitely_missing.cfg")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/shipping/android_presets.cfg", {"justifications": "res://demo/shipping/justifications.json"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Android Permissions Reviewer TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
