## Level Whiteboxing and Snapping tests.
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

const Snap := preload("res://addons/whitebox/core/wbx_snap.gd")


func _init() -> void:
    var op = Snap.new()
    _check("snap pulls a drifted prop onto the grid", op.snap_position(Vector3(2.37, 0, 4)) == Vector3(2, 0, 4), str(op.snap_position(Vector3(2.37, 0, 4))))
    _check("snap honours subdivisions", op.snap_position(Vector3(2.37, 0, 4), 1.0, 2) == Vector3(2.5, 0, 4), str(op.snap_position(Vector3(2.37, 0, 4), 1.0, 2)))
    _check("rotation snaps to the step", absf(op.snap_rotation(37.0, 15.0) - 30.0) < 0.0001)
    _check("steep ramp measures over seventy degrees", absf(op.slope_degrees(Vector3.ZERO, Vector3(1, 3, 0)) - 71.565) < 0.01, str(op.slope_degrees(Vector3.ZERO, Vector3(1, 3, 0))))
    _check("flat ground measures zero", absf(op.slope_degrees(Vector3.ZERO, Vector3(4, 0, 0))) < 0.0001)
    var nodes: Array = op.parse_scene(FileAccess.get_file_as_string("res://demo/whitebox/blockout.tscn"))
    _check("blockout scene parses to six nodes", nodes.size() == 6, str(nodes.size()))
    var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://demo/whitebox/grid.json"))
    var r: Dictionary = op.run(nodes, cfg)
    var kinds := _kinds(r["issues"])
    _check("crate off the grid flagged (gate kind)", kinds.has("off_grid"), str(r["issues"]))
    _check("ramp too steep flagged", kinds.has("steep_slope"))
    var clean: Dictionary = op.run([{"name": "A", "type": "Marker3D", "parent": ".", "origin": Vector3(2, 0, 3)}], cfg)
    _check("on-grid node passes clean", (clean["issues"] as Array).is_empty(), str(clean["issues"]))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Level Whiteboxing and Snapping TESTS")
