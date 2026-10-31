extends SceneTree
const Core := preload("res://addons/type_coverage/core/tcm_meter.gd")
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
    var m: Dictionary = op.measure(FileAccess.get_file_as_string("res://demo/code_health/player.gd"))
    check("untyped health var counted", m["untyped"].any(func(u): return u["what"] == "var `health`"))
    check("inferred := counts as typed", not m["untyped"].any(func(u): return u["what"].contains("total")))
    check("untyped parameters counted", m["untyped"].filter(func(u): return u["what"].contains("of take_damage")).size() == 2)
    check("missing return type counted", m["untyped"].any(func(u): return u["what"] == "return type of _on_died"))
    var small: Dictionary = op.measure("var a: int\nvar b\nconst C = 1\nfunc f(x: int, y) -> void:\n\tpass\n")
    check("exact counts on a small script", small["typed"] == 4 and small["total"] == 6)
    var result: Dictionary = op.run("res://demo/code_health", {"min_percent": 90.0})
    check("player below 90 percent", _has(result, "below_threshold", 0))
    check("project threshold reported", op._count(result, "project_below_threshold") == 1)
    check("report-only by default", op.run("res://demo/code_health")["issues"].is_empty())
    check("_init return not required", op.measure("func _init():\n\tpass\n")["total"] == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir_tcm")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/code_health" if true else "")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Typed GDScript Coverage Meter TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
