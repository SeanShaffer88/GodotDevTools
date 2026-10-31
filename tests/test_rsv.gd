extends SceneTree
const Core := preload("res://addons/report_schema/core/rsv_validator.gd")
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
    var result: Dictionary = op.run("res://demo/suite/after")
    check("three tool reports checked", result["summary"]["reports"] == 3)
    check("issue without severity is a violation", op._count(result, "schema_violation") == 1 and result["issues"].any(func(i): return i["path"].contains("broken_tool")))
    check("results-only report is not a report", op._count(op.run("res://demo/suite/before"), "not_a_report") == 1)
    check("schema document emitted", JSON.parse_string(result["artifacts"]["report.schema.json"])["required"] == ["summary", "issues"])
    check("this repo's own reports validate", op.run("res://reports")["issues"].filter(func(i): return i["kind"] == "schema_violation").is_empty())
    check("missing input is reported", op.run("res://definitely_missing_reports")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/suite/after")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Report Schema TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
