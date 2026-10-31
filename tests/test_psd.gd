extends SceneTree
const Core := preload("res://addons/settings_drift/core/psd_drift.gd")
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
    var o := {"baseline": "res://demo/settings_drift/baseline.cfg"}
    var result: Dictionary = op.run("res://demo/settings_drift/current.cfg", o)
    check("changed max_fps reported", _has(result, "setting_changed", 6))
    check("new vsync setting reported", _has(result, "setting_added", 12))
    check("removed texture filter reported", op._count(result, "setting_removed") == 1)
    check("unchanged keys quiet", not _has(result, "setting_changed", 10))
    check("ignore prefixes skip keys", op._count(op.run("res://demo/settings_drift/current.cfg", {"baseline": o["baseline"], "ignore": ["physics/", "rendering/", "display/"]}), "setting_added") == 0)
    check("missing baseline is bad input", op.run("res://demo/settings_drift/current.cfg", {"baseline": "res://nope.cfg"})["issues"][0]["kind"] == "bad_input")
    check("missing input is reported", op.run("res://definitely_missing.godot")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/settings_drift/current.cfg", {"baseline": "res://demo/settings_drift/baseline.cfg"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Project Settings Drift Report TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
