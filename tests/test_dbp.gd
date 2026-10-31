## Draw Call and Batching Profiler tests.
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

const Profiler := preload("res://addons/batch_profiler/core/dbp_profiler.gd")


func _init() -> void:
    var op = Profiler.new()
    var r: Dictionary = op.run()
    _check("project scan sees scenes", int(r["summary"]["scenes"]) >= 5, str(r["summary"]))
    var found_material := false
    var found_z := false
    var found_light := false
    for i in r["issues"]:
        if str(i["path"]) == "res://demo/batching/market.tscn":
            match str(i["kind"]):
                "material_switch": found_material = true
                "z_interleave": found_z = true
                "light_pass": found_light = true
    _check("market fixture: material switches flagged", found_material)
    _check("market fixture: z interleaving flagged", found_z)
    _check("market fixture: light pass flagged", found_light)
    var clean: Dictionary = op.run("[gd_scene format=3]\n\n[node name=\"Solo\" type=\"Sprite2D\" parent=\".\"]\n", "synthetic.tscn")
    _check("clean synthetic scene has no findings", (clean["issues"] as Array).is_empty(), str(clean["issues"]))
    var nodes: Array = op.parse_scene(FileAccess.get_file_as_string("res://demo/batching/market.tscn"))
    _check("parse_scene reads the five market nodes", nodes.size() == 5, str(nodes.size()))
    var j = JSON.parse_string(op.to_json(r))
    _check("to_json round-trips", typeof(j) == TYPE_DICTIONARY and (j as Dictionary).has("summary"))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Draw Call and Batching Profiler TESTS")
