extends SceneTree
const Core := preload("res://addons/third_party_notices/core/tpn_collector.gd")
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
    var result: Dictionary = op.run("res://demo/shipping/vendor")
    check("three packages found", result["summary"]["packages"] == 3)
    check("MIT identified", result["packages"].any(func(r): return r["license"] == "MIT"))
    check("package without license flagged", op._count(result, "missing_license") == 1)
    check("GPL flagged for review", op._count(result, "copyleft_review") == 1)
    check("notices text includes MIT body", result["notices_text"].contains("Permission is hereby granted"))
    check("repo addons folder scanned as packages", op.run("res://addons")["summary"]["packages"] > 40)
    check("missing input is reported", op.run("res://definitely_missing_dir")["issues"][0]["kind"] == "scan_error")
    var r: Dictionary = op.run("res://demo/shipping/vendor")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Third-Party Notice Collector TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
