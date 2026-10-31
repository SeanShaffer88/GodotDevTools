extends SceneTree
const Core := preload("res://addons/state_coverage/core/coverage_audit.gd")
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
    check("empty model rejected", kinds(op.analyze({"transitions": []}, {"transitions": []})).has("input_error"))
    check("invalid input shape reported", kinds(op.analyze({}, {})).has("input_error"))
    check("missing file reported", kinds(op.run("res://nonexistent_batch_fixture.json", "res://nonexistent_batch_fixture.json")).has("input_error"))
    check("markdown report renders", op.to_markdown(fixture).begins_with("# "))
    check("JSON report parses", JSON.parse_string(op.to_json(fixture)).has("issues"))
    print("state_coverage TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
