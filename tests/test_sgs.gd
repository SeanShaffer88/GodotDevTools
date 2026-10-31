## Signal Flow and Event Bus Spy tests.
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

const Analyzer := preload("res://addons/signal_spy/core/sgs_analyzer.gd")


func _init() -> void:
    var op = Analyzer.new()
    var loaded := op.load_session("res://demo/signals/session.json")
    _check("fixture session loads", (loaded["errors"] as Array).is_empty(), str(loaded["errors"]))
    var r: Dictionary = op.analyze(loaded["session"])
    var kinds := _kinds(r["issues"])
    _check("runaway heartbeat flagged (gate kind)", kinds.has("runaway"), str(r["issues"]))
    _check("recursive item_pickup flagged", kinds.has("recursive_signal"))
    _check("deep cascade flagged", kinds.has("deep_cascade"))
    _check("orphan handle flagged", kinds.has("orphan_handle"))
    var stats: Dictionary = r["stats"]
    _check("damage_taken latency measured", int((stats["damage_taken"] as Dictionary)["avg_latency_usec"]) == 150, str(stats["damage_taken"]))
    _check("quest_updated dropped without a listener", int((stats["quest_updated"] as Dictionary)["dropped"]) == 1)
    var missing := op.load_session("res://demo/signals/nope.json")
    _check("missing session file is an error", _kinds(missing["errors"]).has("missing_file"))
    var shuffled: Dictionary = op.analyze({"events": [{"fire_id": "a", "t_usec": 500, "signal": "s", "kind": "emit", "depth": 0}, {"fire_id": "b", "t_usec": 100, "signal": "s2", "kind": "emit", "depth": 0}]})
    _check("backwards timestamps are caught", _kinds(shuffled["issues"]).has("out_of_order"))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Signal Flow and Event Bus Spy TESTS")
