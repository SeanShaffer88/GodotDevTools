extends SceneTree
const Core := preload("res://addons/warning_baseline/core/gwb_baseline.gd")
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
    var ws: Array = op.warnings(FileAccess.get_file_as_string("res://demo/ci/warnings/inventory.gd"))
    check("unused parameter source found", ws.any(func(w): return w["code"] == "UNUSED_PARAMETER" and w["detail"] == "source"))
    check("two unused locals found", ws.filter(func(w): return w["code"] == "UNUSED_VARIABLE").size() == 2)
    check("code after return found", ws.any(func(w): return w["code"] == "UNREACHABLE_CODE" and w["line"] == 10))
    check("underscore parameters exempt", not ws.any(func(w): return w["detail"] == "_value"))
    var result: Dictionary = op.run("res://demo/ci/warnings", {"baseline": "res://demo/ci/warnings/baseline.json"})
    check("variable and unreachable counts rose", op._count(result, "warning_increase") == 2)
    check("suggested baseline offered", result["suggested_baseline"]["res://demo/ci/warnings/inventory.gd"]["UNUSED_VARIABLE"] == 2)
    check("no baseline means report only", op.run("res://demo/ci/warnings")["issues"].is_empty())
    check("new file with warnings flagged", op._count(op.analyze({"res://n.gd": "func f(a):\n\tpass\n"}, {"baseline_data": {}, "has_baseline": true}), "new_warning_file") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_gwb")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/ci/warnings", {"baseline": "res://demo/ci/warnings/baseline.json"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("GDScript Warning Baseline TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
