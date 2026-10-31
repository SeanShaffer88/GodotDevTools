## Behaviour Tree and State Machine Debugger tests.
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

const Machine := preload("res://addons/bt_debugger/core/btd_machine.gd")


func _init() -> void:
    var op = Machine.new()
    var loaded := op.load_definition("res://demo/ai/guard_bt.json")
    _check("fixture definition loads", (loaded["errors"] as Array).is_empty(), str(loaded["errors"]))
    var definition: Dictionary = loaded["definition"]
    var found: Array = op.validate(definition)
    var kinds := _kinds(found)
    _check("transition to undefined chase flagged (gate kind)", kinds.has("missing_state"), str(found))
    _check("forgotten state is unreachable and empty", kinds.has("unreachable_state") and kinds.has("no_entry"))
    _check("guard passes when the blackboard says so", op.check_condition({"key": "noise_level", "op": "gt", "value": 0.5}, {"noise_level": 0.9}))
    _check("guard fails when the blackboard disagrees", not op.check_condition({"key": "noise_level", "op": "gt", "value": 0.5}, {"noise_level": 0.1}))
    var trace: Array = []
    var bb := {"noise_level": 0.1}
    var next_state: String = op.step("idle", definition, bb, trace)
    _check("idle holds while it is quiet", next_state == "", str(trace))
    bb["noise_level"] = 0.9
    next_state = op.step("idle", definition, bb, trace)
    _check("idle moves to alert on noise", next_state == "alert", str(next_state))
    var clean_def := {"initial": "a", "states": [{"name": "a", "tree": {"type": "action", "name": "noop"}, "on_enter": {"set": {"ticks": 1}}}, {"name": "b", "tree": {"type": "action", "name": "rest"}}], "transitions": [{"from": "a", "to": "b", "when": {"key": "ticks", "op": "gte", "value": 1}}]}
    var clean: Dictionary = op.run(clean_def)
    _check("a valid machine runs and halts at b", int(clean["summary"]["ticks"]) == 2 and (clean["issues"] as Array).is_empty(), str(clean))
    var invalid: Dictionary = op.run(definition)
    _check("an invalid machine does not tick", int(invalid["summary"]["ticks"]) == 0, str(invalid["summary"]))
    _check("to_markdown renders the trace", op.to_markdown(clean).contains("## Trace"))
    _finish("Behaviour Tree and State Machine Debugger TESTS")
