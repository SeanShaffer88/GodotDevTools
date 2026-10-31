extends SceneTree
const Core := preload("res://addons/suppressions/core/fsb_baseline.gd")
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
    var o := {"suppressions": "res://demo/suite/suppressions.json", "today": "2026-10-31"}
    var result: Dictionary = op.run("res://demo/suite/after", o)
    check("one finding suppressed", result["summary"]["suppressed"] == 1)
    check("three findings remain", op._count(result, "unsuppressed_finding") == 3)
    check("expired suppression reported and ignored", op._count(result, "expired_suppression") == 1)
    check("empty justification refused", op._count(result, "missing_justification") == 1)
    check("stale suppression reported", op._count(result, "unused_suppression") == 1)
    check("remaining keep their severity", result["issues"].any(func(i): return i["kind"] == "unsuppressed_finding" and i["severity"] == "error"))
    check("before expiry it applies", op.run("res://demo/suite/after", {"suppressions": o["suppressions"], "today": "2026-01-01"})["summary"]["suppressed"] == 2)
    check("missing input is reported", op.run("res://definitely_missing_reports", {"suppressions": "res://demo/suite/suppressions.json"})["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/suite/after", {"suppressions": "res://demo/suite/suppressions.json", "today": "2026-10-31"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Finding Suppression Baseline TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
