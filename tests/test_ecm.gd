extends SceneTree
const Core := preload("res://addons/env_cost/core/ecm_matrix.gd")
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
    var result: Dictionary = op.run("res://demo/rendering", {"renderer": "forward_plus"})
    check("one environment found", result["summary"]["environments"] == 1)
    check("five features listed", result["environments"][0]["features"].size() == 5)
    check("three high-tier features over medium", op._count(result, "expensive_feature") == 3)
    check("high allows everything", op._count(op.run("res://demo/rendering", {"renderer": "forward_plus", "max_cost": "high"}), "expensive_feature") == 0)
    check("compatibility lacks four of them", op._count(op.run("res://demo/rendering", {"renderer": "gl_compatibility", "max_cost": "high"}), "unsupported_in_renderer") == 4)
    check("bad tier rejected", op.run("res://demo/rendering", {"max_cost": "ultra"})["issues"][0]["kind"] == "bad_input")
    check("standalone Environment resource read", op.analyze({"res://e.tres": "[gd_resource type=\"Environment\" format=3]\n[resource]\nssr_enabled = true\n"})["summary"]["environments"] == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_ecm")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/rendering", {"renderer": "forward_plus"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Environment Feature Cost Matrix TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
