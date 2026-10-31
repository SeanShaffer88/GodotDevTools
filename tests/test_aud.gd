## Audio Mixing Sandbox tests.
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

const Mixer := preload("res://addons/audio_sandbox/core/aud_mixer.gd")


func _init() -> void:
    var op = Mixer.new()
    var layout = JSON.parse_string(FileAccess.get_file_as_string("res://demo/audio/mix_layout.json"))
    var r: Dictionary = op.run(layout)
    _check("ducking loop detected (gate kind)", _kinds(r["issues"]).has("duck_loop"), str(r["issues"]))
    _check("stuck reverb zone detected", _kinds(r["issues"]).has("zone_stuck"))
    _check("voice budget evicted the lowest priority voice", int(r["summary"]["evictions"]) == 1 and _kinds(r["issues"]).has("voice_eviction"), str(r["summary"]))
    var ducked := -1.0
    var released := -1.0
    for row in r["timeline"]:
        if int(row["t_ms"]) == 500:
            ducked = float((row["gains"] as Dictionary).get("Music", 0.0))
        if int(row["t_ms"]) == 1300:
            released = float((row["gains"] as Dictionary).get("Music", 0.0))
    _check("music fully ducked while VO holds", absf(ducked + 8.0) < 0.001, str(ducked))
    _check("music released after the release ramp", absf(released) < 0.001, str(released))
    var broken: Dictionary = op.run({"buses": [{"name": "Master"}], "ducks": [{"trigger": "Ghost", "target": "Master", "db": -6}], "events": []})
    _check("duck rule referencing a missing bus is an error", _kinds(broken["issues"]).has("missing_bus"), str(broken["issues"]))
    var again: Dictionary = op.run(layout)
    _check("simulation is deterministic", op.to_json(r) == op.to_json(again))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Audio Mixing Sandbox TESTS")
