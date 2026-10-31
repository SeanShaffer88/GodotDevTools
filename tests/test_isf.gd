extends SceneTree
const Core := preload("res://addons/input_fuzzer/core/isf_fuzzer.gd")
var op = Core.new()
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _has(result: Dictionary, kind: String, line: int) -> bool:
    for issue in result["issues"]:
        if issue["kind"] == kind and int(issue["line"]) == line:
            return true
    return false

func _init() -> void:
    var acts: Dictionary = op.actions(FileAccess.get_file_as_string("res://demo/ci/input_actions.godot"))
    check("four actions read, dash unbound", acts.size() == 4 and acts["jump"] and not acts["dash"])
    var result: Dictionary = op.run("res://demo/ci/input_actions.godot")
    check("unbound dash reported", op._count(result, "unbound_action") == 1)
    check("five sequences of sixty steps", result["sequences"].size() == 5 and result["sequences"][0]["steps"].size() == 60)
    check("same seed, same sequences", JSON.stringify(op.run("res://demo/ci/input_actions.godot")["sequences"]) == JSON.stringify(result["sequences"]))
    check("different seed differs", JSON.stringify(op.run("res://demo/ci/input_actions.godot", {"seed": 2})["sequences"]) != JSON.stringify(result["sequences"]))
    check("holds bounded", result["sequences"].all(func(s): return s["steps"].all(func(st): return int(st["hold"]) <= 30 and st["action"] != "dash")))
    var seq := {"steps": [{"frame": 2, "action": "jump", "hold": 3}, {"frame": 5, "action": "fire", "hold": 1}]}
    check("release before press on the same frame", op.events_for_frame(seq, 5) == [["jump", false], ["fire", true]])
    check("no actions is an error", op.evaluate({"dash": false})["issues"].any(func(i): return i["kind"] == "no_actions"))
    var player = preload("res://addons/input_fuzzer/runtime/isf_player.gd").new()
    player.play(seq)
    check("runtime player computes the last frame", player._last == 6)
    player.free()
    check("missing input is reported", op.run("res://definitely_missing.godot")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/ci/input_actions.godot")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Input Sequence Fuzzer TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
