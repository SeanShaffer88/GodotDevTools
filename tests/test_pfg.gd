## Prefab and Variant Instance Guard tests.
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

const Differ := preload("res://addons/prefab_guard/core/pfg_diff.gd")


func _init() -> void:
    var op = Differ.new()
    var scene_text := FileAccess.get_file_as_string("res://demo/prefabs/room.tscn")
    var ext: Dictionary = op.parse_ext_scenes(scene_text)
    _check("ext scene resolved", str(ext.get("1_prop", "")) == "res://demo/prefabs/prop.tscn", str(ext))
    var prefab_text := FileAccess.get_file_as_string("res://demo/prefabs/prop.tscn")
    var defaults: Dictionary = op.prefab_defaults(prefab_text)
    _check("prefab defaults read from the root node", str(defaults.get("position", "")) == "Vector2(0, 0)" and str(defaults.get("scale", "")) == "Vector2(1, 1)", str(defaults))
    var r: Dictionary = op.analyze(scene_text, "res://demo/prefabs/room.tscn", {"res://demo/prefabs/prop.tscn": prefab_text})
    var kinds := _kinds(r["issues"])
    _check("PropA placement hides the prefab position (gate kind)", kinds.has("drifted_property"), str(r["issues"]))
    _check("PropB scale override is dead weight", kinds.has("default_drift"))
    var plan_hit := false
    for plan_row in r["plan"]:
        if str((plan_row as Dictionary)["op"]) == "remove_override" and str((plan_row as Dictionary)["node"]) == "PropB":
            plan_hit = true
    _check("rollback plan removes the dead override", plan_hit, str(r["plan"]))
    _check("summary counts two instances", int(r["summary"]["instances"]) == 2, str(r["summary"]))
    var missing: Dictionary = op.analyze(scene_text, "res://demo/prefabs/room.tscn", {})
    _check("unreadable prefab reported", _kinds(missing["issues"]).has("prefab_missing"), str(missing["issues"]))
    _check("to_markdown renders the plan section", op.to_markdown(r).contains("Rollback plan"))
    _finish("Prefab and Variant Instance Guard TESTS")
