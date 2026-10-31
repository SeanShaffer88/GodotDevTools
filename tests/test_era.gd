extends SceneTree
const Core := preload("res://addons/export_ranges/core/era_auditor.gd")
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
    var result: Dictionary = op.run("res://demo/export_ranges")
    check("scene value above max flagged", _has(result, "out_of_range", 7))
    check("in-range scene value passes", not _has(result, "out_of_range", 8))
    check("default above max flagged", _has(result, "default_out_of_range", 4))
    check("or_greater lifts the max", not _has(result, "default_out_of_range", 6))
    check("unhinted exports off by default", op._count(result, "no_range_hint") == 0)
    check("unhinted export listed on request", _has(op.run("res://demo/export_ranges", {"report_unhinted": true}), "no_range_hint", 5))
    var rr: Dictionary = op.ranges("@export_range(-5, 5, 1, \"or_less\") var v := -9\n")
    check("or_less parsed", rr["v"]["open_min"] and not op._outside(-9.0, rr["v"]))
    check("missing input is reported", op.run("res://definitely_missing_dir_era")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/export_ranges")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Export Variable Range Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
