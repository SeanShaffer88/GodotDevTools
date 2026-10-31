extends SceneTree
const Core := preload("res://addons/theme_audit/core/tra_auditor.gd")
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
    var result: Dictionary = op.run("res://demo/rendering")
    check("nine distinct font sizes collected", result["summary"]["font_sizes"] == 9)
    check("font size sprawl flagged", op._count(result, "font_size_sprawl") == 1)
    check("21/22 and 17/18 near duplicates", op._count(result, "near_duplicate_sizes") == 2)
    check("DangerButton variation unused", op._count(result, "unused_variation") == 1 and result["issues"].any(func(i): return i["message"].contains("DangerButton")))
    check("override sprawl below default limit", op._count(result, "override_sprawl") == 0)
    check("override limit configurable", op._count(op.run("res://demo/rendering", {"max_overrides": 5}), "override_sprawl") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_tra")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/rendering")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Theme Resource Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
