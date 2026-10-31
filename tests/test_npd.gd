extends SceneTree
const Core := preload("res://addons/property_drift/core/npd_monitor.gd")
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
    var result: Dictionary = op.run("res://demo/workflow/drift")
    check("two conventions learned", result["summary"]["conventions"] == 2)
    check("the odd label drifts twice", op._count(result, "property_outlier") == 2 and result["issues"].all(func(i): return i["message"].begins_with("Label4")))
    check("text values ignored", not result["issues"].any(func(i): return i["message"].contains(".text")))
    var base := {"Label": {"horizontal_alignment": "1", "autowrap_mode": "3"}}
    var b: Dictionary = op.analyze({"res://m.tscn": FileAccess.get_file_as_string("res://demo/workflow/drift/menu.tscn")}, {"baseline_data": base})
    check("baseline mode compares defaults too", op._count(b, "baseline_mismatch") == 6)
    check("small samples learn nothing", op.run("res://demo/workflow/drift", {"min_nodes": 10})["summary"]["conventions"] == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir")["issues"][0]["kind"] == "scan_error")
    var r: Dictionary = op.run("res://demo/workflow/drift")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Node Property Drift Monitor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
