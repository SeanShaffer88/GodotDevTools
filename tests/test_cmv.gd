## Physics Collision Matrix tests.
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

const Matrix := preload("res://addons/collision_matrix/core/cmv_matrix.gd")


func _init() -> void:
    var op = Matrix.new()
    _check("popcount of twenty bits", op.popcount(1048575) == 20)
    _check("popcount of zero", op.popcount(0) == 0)
    var bodies: Array = op.parse_scene(FileAccess.get_file_as_string("res://demo/collision/arena.tscn"), "res://demo/collision/arena.tscn")
    var has_everything := false
    for b in bodies:
        if str(b["name"]) == "EverythingBody" and int(b["layer"]) == 1048575:
            has_everything = true
    _check("arena fixture parses with its huge mask", has_everything, str(bodies))
    var r: Dictionary = op.run()
    var found_all := false
    var found_ray := false
    for i in r["issues"]:
        if str(i["path"]) == "res://demo/collision/arena.tscn":
            if str(i["kind"]) == "all_vs_all": found_all = true
            if str(i["kind"]) == "redundant_raycast_layer": found_ray = true
    _check("all-vs-all body flagged (gate kind)", found_all)
    _check("raycast with a layer flagged", found_ray)
    var single: Dictionary = op.analyze([{"name": "A", "type": "Area2D", "path": "t", "layer": 1, "mask": 1}], {0: "world"})
    _check("single matched pair: one candidate combination", int(single["summary"]["candidate_pairs"]) == 1 and (single["issues"] as Array).is_empty(), str(single))
    var lonely: Dictionary = op.analyze([{"name": "L", "type": "StaticBody2D", "path": "t", "layer": 2, "mask": 0}, {"name": "Q", "type": "Area2D", "path": "t", "layer": 0, "mask": 4}], {1: "a", 2: "b"})
    _check("declared-but-unqueried and queried-but-undeclared bits reported", _kinds(lonely["issues"]).has("unused_layer") and _kinds(lonely["issues"]).has("dead_mask"), str(lonely["issues"]))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Physics Collision Matrix TESTS")
