extends SceneTree
const Core := preload("res://addons/state_coverage/core/coverage_audit.gd")
const Recorder := preload("res://addons/state_coverage/core/coverage_recorder.gd")
const RuntimeNode := preload("res://addons/state_coverage/runtime/coverage_node.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label)

func kinds(result: Dictionary) -> Array:
    var result_kinds: Array = []
    for issue in result["issues"]:
        result_kinds.append(issue["kind"])
    return result_kinds

func _init() -> void:
    var op = Core.new()
    var fixture: Dictionary = op.run("res://demo/state_coverage/model.json", "res://demo/state_coverage/trace.json")
    check("uncovered transition found", kinds(fixture).has("uncovered_transition"))
    var model := {"transitions": [{"from": "a", "to": "b"}]}
    check("covered transition passes", op.analyze(model, {"transitions": [{"from": "a", "to": "b"}]})["issues"].is_empty())
    check("unexpected transition found", kinds(op.analyze(model, {"transitions": [{"from": "b", "to": "a"}]})).has("unexpected_transition"))
    check("invalid transition rejected", kinds(op.analyze(model, {"transitions": [{"from": "a"}]})).has("invalid_transition"))
    check("duplicate declaration rejected", kinds(op.analyze({"transitions": [{"from": "a", "to": "b"}, {"from": "a", "to": "b"}]}, {"transitions": []})).has("duplicate_transition"))
    var repeated: Dictionary = op.analyze(model, {"transitions": [{"from": "a", "to": "b"}, {"from": "a", "to": "b"}]})
    check("repeated transitions counted", repeated["rows"][0]["count"] == 2)
    var recorder = Recorder.new()
    recorder.max_transitions = 2
    check("recorder rejects empty names", not recorder.record_transition("", "idle"))
    check("recorder records transitions", recorder.record_transition("a", "b") and recorder.record_transition("b", "a"))
    recorder.start_sequence()
    check("recorder records new sequence", recorder.record_transition("a", "b"))
    var snapshot: Dictionary = recorder.snapshot()
    check("bounded recorder reports dropped records", snapshot["truncated"] and snapshot["dropped"] == 1 and snapshot["transitions"].size() == 2)
    check("sequence reset marked", snapshot["transitions"][1]["reset"] == true)
    snapshot["transitions"].clear()
    check("snapshot is detached", recorder.snapshot()["transitions"].size() == 2)
    check("truncated trace warns", kinds(op.analyze(model, recorder.snapshot())).has("truncated_trace"))
    recorder.clear()
    check("clear resets trace", recorder.snapshot()["transitions"].is_empty() and not recorder.snapshot()["truncated"])
    recorder.max_transitions = 0
    check("invalid buffer rejected", not recorder.record_transition("a", "b"))
    var gap_trace := {"transitions": [{"from": "a", "to": "b"}, {"from": "a", "to": "b"}]}
    check("continuity is opt-in", not kinds(op.analyze(model, gap_trace)).has("trace_discontinuity"))
    check("continuity detects gap", kinds(op.analyze(model, gap_trace, true)).has("trace_discontinuity"))
    gap_trace["transitions"][1]["reset"] = true
    check("sequence reset suppresses gap", not kinds(op.analyze(model, gap_trace, true)).has("trace_discontinuity"))
    gap_trace["transitions"][1]["reset"] = "yes"
    check("invalid reset flagged", kinds(op.analyze(model, gap_trace, true)).has("invalid_transition"))
    check("invalid truncation flag rejected", kinds(op.analyze(model, {"transitions": [], "truncated": "yes"})).has("input_error"))
    var node = RuntimeNode.new()
    check("runtime node records", node.record_transition("a", "b"))
    node.recording = false
    check("runtime pause stops recording", not node.record_transition("b", "a") and node.snapshot()["transitions"].size() == 1)
    var trace_path := "user://state_coverage_test_trace.json"
    check("runtime trace writes", node.save_trace(trace_path) == OK)
    check("saved trace interoperates with audit", not kinds(op.run("res://demo/state_coverage/model.json", trace_path)).has("input_error"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(trace_path))
    node.free()
    check("empty model rejected", kinds(op.analyze({"transitions": []}, {"transitions": []})).has("input_error"))
    check("invalid input shape reported", kinds(op.analyze({}, {})).has("input_error"))
    check("missing file reported", kinds(op.run("res://nonexistent_batch_fixture.json", "res://nonexistent_batch_fixture.json")).has("input_error"))
    check("markdown report renders", op.to_markdown(fixture).begins_with("# "))
    check("JSON report parses", JSON.parse_string(op.to_json(fixture)).has("issues"))
    print("state_coverage TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
