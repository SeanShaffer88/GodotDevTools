## Dialogue and Quest Debugger tests.
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

const Graph := preload("res://addons/dialogue_quest/core/dqd_graph.gd")


func _init() -> void:
    var op = Graph.new()
    var files := op.find_files()
    _check("finds the story file", files.has("res://demo/dialogue/story.json"), str(files))
    var loaded: Dictionary = op.load_files(files)
    _check("story loads without errors", (loaded["errors"] as Array).is_empty(), str(loaded))
    var r: Dictionary = op.analyse()
    var kinds := _kinds(r["issues"])
    _check("counts dialogues and quests", int(r["summary"]["dialogues"]) == 1 and int(r["summary"]["quests"]) == 5, str(r["summary"]))
    _check("missing choice target flagged (ghost_node)", kinds.has("missing_target"), str(kinds))
    _check("unreachable node flagged (secret_room)", kinds.has("unreachable_node"))
    _check("missing quest requirement flagged (crown_jewel)", kinds.has("missing_quest_requirement"))
    _check("quest cycle flagged (cycle_a/cycle_b)", kinds.has("quest_cycle"))
    _check("condition: met_guard false blocks the choice", not op.eval_condition({"var": "met_guard", "op": "==", "value": true}, {"met_guard": false}))
    _check("condition: gold >= 5 passes at 5", op.eval_condition({"var": "gold", "op": ">=", "value": 5}, {"gold": 5}))
    _check("condition: gold >= 5 fails at 3", not op.eval_condition({"var": "gold", "op": ">=", "value": 5}, {"gold": 3}))
    var s1: Dictionary = op.simulate("tavern", [0], {"met_guard": false, "gold": 10})
    _check("simulate without met_guard: first open choice is Leave", s1["visited"] == ["intro", "bye"] and s1["stopped"] == "ended", str(s1))
    var s2: Dictionary = op.simulate("tavern", [0], {"met_guard": true, "gold": 10})
    _check("simulate with met_guard: reaches the guard", s2["visited"] == ["intro", "guard"] and s2["stopped"] == "awaiting_pick", str(s2))
    _check("simulate shows the gold-gated choice as available", (s2["available"] as Array).has("Pay 5 gold"), str(s2))
    var s3: Dictionary = op.simulate("tavern", [0, 0], {"met_guard": true, "gold": 10})
    _check("simulate paying reaches the ending and applies effects", s3["visited"] == ["intro", "guard", "paid"] and bool(s3["state"].get("gold_paid", false)), str(s3))
    var s4: Dictionary = op.simulate("tavern", [0, 0], {"met_guard": true, "gold": 2})
    _check("simulate broke: Pay choice is closed, Walk away taken", s4["visited"] == ["intro", "guard", "bye"], str(s4))
    _finish("DQD TESTS")
