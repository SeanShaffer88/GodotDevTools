extends SceneTree
const Core := preload("res://addons/controller_course/core/cct_course.gd")
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
    var result: Dictionary = op.run("res://demo/runtime_perf/controller.json")
    check("jump peaks at 90", is_equal_approx(float(result["summary"]["jump_height"]), 90.0))
    check("reach includes coyote time", is_equal_approx(float(result["summary"]["jump_reach"]), 210.57))
    check("128 wall unreachable", op._count(result, "unreachable_ledge") == 1)
    check("260 canyon unjumpable", op._count(result, "unjumpable_gap") == 1)
    check("52 degree path too steep", op._count(result, "too_steep_slope") == 1)
    check("1-frame coyote window flagged", op._count(op.evaluate({"physics_fps": 60, "controller": {"gravity": 1, "jump_velocity": 1, "coyote_time": 0.02}, "course": []}), "short_grace_window") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/runtime_perf/controller.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Character Controller Test Course TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
