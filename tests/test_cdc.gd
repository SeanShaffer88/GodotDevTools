extends SceneTree
const Core := preload("res://addons/content_descriptor/core/cdc_checklist.gd")
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
    var o := {"today": "2026-10-31"}
    var result: Dictionary = op.run("res://demo/shipping/descriptors.json", o)
    check("three of four answered", result["summary"]["answered"] == 3)
    check("online question unanswered", op._count(result, "unanswered") == 1)
    check("moderate is not an allowed option", op._count(result, "invalid_answer") == 1)
    check("purchases lack evidence", op._count(result, "missing_evidence") == 1)
    check("2025 review is stale", op._count(result, "stale_answer") == 1)
    check("age limit configurable", op._count(op.run("res://demo/shipping/descriptors.json", {"today": "2026-10-31", "max_age_days": 1000}), "stale_answer") == 0)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/shipping/descriptors.json", {"today": "2026-10-31"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Content Descriptor Checklist TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
