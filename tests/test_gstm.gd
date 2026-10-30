## Time Machine tests.
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

const Recorder := preload("res://addons/time_machine/core/gstm_recorder.gd")


func _init() -> void:
    var rec = Recorder.new()
    for i in 5:
        var inputs: Array = [{"action": "jump", "pressed": true}] if i == 2 else []
        rec.record(inputs, {"hp": 10 - i, "x": i * 4})
    _check("records frames", rec.frame_count() == 5)
    _check("snapshot at frame 2", int(rec.snapshot_at(2)["hp"]) == 8 and int(rec.snapshot_at(2)["x"]) == 8)
    var snap := rec.snapshot_at(2)
    snap["hp"] = 999
    _check("snapshots are copies - history cannot be rewritten", int(rec.snapshot_at(2)["hp"]) == 8)
    _check("inputs recorded on their frame", (rec.inputs_at(2) as Array).size() == 1 and rec.inputs_at(1).is_empty())
    var script: Array = rec.replay_script(0, 4)
    _check("replay script carries frame tags", script.size() == 1 and int(script[0]["frame"]) == 2, str(script))
    var diff: Dictionary = rec.diff_states(0, 4)
    _check("diff shows hp and x changed", diff.has("hp") and diff.has("x") and int(diff["hp"]["to"]) == 6, str(diff))
    _check("state hash stable for same state", rec.state_hash(2) == rec.state_hash(2) and rec.state_hash(2) != rec.state_hash(3))
    _check("save session", rec.save_session("user://gstm_test_session.json"))
    var rec2 = Recorder.new()
    _check("load session", rec2.load_session("user://gstm_test_session.json"))
    _check("loaded snapshot matches", int(rec2.snapshot_at(3)["hp"]) == 7)
    var v: Dictionary = rec.verify_session("res://demo/time_machine/example_session.json")
    _check("example session verifies clean", int(v["summary"]["frames"]) == 3 and int(v["summary"]["inputs"]) == 2 and (v["issues"] as Array).is_empty(), str(v))
    var bad: Dictionary = rec.verify_session("res://demo/time_machine/nope.json")
    _check("missing session reported", _kinds(bad["issues"]).has("missing_session"))
    _finish("GSTM TESTS")
