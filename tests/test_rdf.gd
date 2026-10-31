extends SceneTree
const Core := preload("res://addons/report_diff/core/rdf_diff.gd")
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
    var result: Dictionary = op.run("res://demo/suite/before", {"after": "res://demo/suite/after"})
    check("two new findings", result["summary"]["new"] == 2)
    check("one fixed finding", result["summary"]["fixed"] == 1 and result["issues"].any(func(i): return i["kind"] == "fixed_finding" and i["message"].contains("duplicate")))
    check("moved line still unchanged", result["summary"]["unchanged"] == 2)
    check("message numbers masked in keys", op.key("t", {"kind": "k", "message": "x 12 y"}) == op.key("t", {"kind": "k", "message": "x 99 y"}))
    check("duplicate finding counts as new", op.evaluate({"t": {"issues": [{"severity": "info", "kind": "k", "message": "m"}]}}, {"t": {"issues": [{"severity": "info", "kind": "k", "message": "m"}, {"severity": "info", "kind": "k", "message": "m"}]}})["summary"]["new"] == 1)
    check("missing input is reported", op.run("res://definitely_missing_reports", {"after": "res://demo/suite/after"})["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/suite/before", {"after": "res://demo/suite/after"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Report Diff TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
