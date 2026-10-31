extends SceneTree
const Core := preload("res://addons/cert_check/core/cert_audit.gd")
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
    var fixture: Dictionary = op.run("res://demo/cert_check/profile.json", "res://demo/cert_check/results.json")
    check("fixture failure found", kinds(fixture).has("failed_check"))
    var profile := {"requirements": [{"id": "x", "evidence_required": true}]}
    check("passing evidence accepted", op.analyze(profile, {"checks": {"x": {"status": "pass", "evidence": "log"}}})["issues"].is_empty())
    check("missing evidence found", kinds(op.analyze(profile, {"checks": {"x": {"status": "pass"}}})).has("missing_evidence"))
    check("missing result found", kinds(op.analyze(profile, {"checks": {}})).has("missing_check"))
    check("skipped result found", kinds(op.analyze(profile, {"checks": {"x": {"status": "skip"}}})).has("skipped_check"))
    check("unknown result found", kinds(op.analyze(profile, {"checks": {"other": {"status": "pass"}}})).has("unknown_check"))
    check("duplicate requirement rejected", kinds(op.analyze({"requirements": [{"id": "x"}, {"id": "x"}]}, {"checks": {}})).has("duplicate_requirement"))
    check("invalid status rejected", kinds(op.analyze(profile, {"checks": {"x": {"status": "other"}}})).has("invalid_check"))
    check("empty checklist rejected", kinds(op.analyze({"requirements": []}, {"checks": {}})).has("input_error"))
    check("invalid input shape reported", kinds(op.analyze({}, {})).has("input_error"))
    check("missing file reported", kinds(op.run("res://nonexistent_batch_fixture.json", "res://nonexistent_batch_fixture.json")).has("input_error"))
    check("markdown report renders", op.to_markdown(fixture).begins_with("# "))
    check("JSON report parses", JSON.parse_string(op.to_json(fixture)).has("issues"))
    print("cert_check TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
