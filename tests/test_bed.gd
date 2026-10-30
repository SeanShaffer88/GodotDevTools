## Export Doctor tests.
extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0


func _check(label: String, ok: bool, evidence: String = "") -> void:
    if ok:
        _passes += 1
        print("PASS  ", label)
    else:
        _failures.append(label)
        print("FAIL  ", label, "  ", evidence)


func _finish(name: String) -> void:
    print("----")
    print(name, ": %d passed, %d failed" % [_passes, _failures.size()])
    quit(1 if not _failures.is_empty() else 0)


func _kinds(issues: Array) -> Array:
    var out: Array = []
    for i in issues:
        out.append(i["kind"])
    return out

const Doctor := preload("res://addons/export_doctor/core/bed_doctor.gd")


func _init() -> void:
    var op = Doctor.new()
    var r: Dictionary = op.diagnose()
    var kinds := _kinds(r["issues"])
    _check("doctor runs many checks", int(r["summary"]["checks"]) >= 8, str(r["summary"]))
    _check("both presets found", int(r["summary"]["presets"]) == 2, str(r["summary"]))
    _check("missing preset icon flagged as error", kinds.has("preset_missing_icon"), str(kinds))
    _check("empty export path flagged", kinds.has("preset_no_path"))
    _check("healthy main scene not flagged", not kinds.has("no_main_scene") and not kinds.has("missing_main_scene"))
    _check("healthy scripts not flagged", not kinds.has("script_parse"), str(kinds))
    var has_fix := true
    for i in r["issues"]:
        if str(i.get("fix", "")) == "":
            has_fix = false
    _check("every finding carries a fix", has_fix)
    _finish("BED TESTS")
