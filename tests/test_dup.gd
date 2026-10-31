extends SceneTree
const Core := preload("res://addons/duplicate_code/core/dup_detector.gd")
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
    var result: Dictionary = op.run("res://demo/code_health")
    check("scoring loop duplicated across files", result["summary"]["groups"] == 1)
    var g: Dictionary = result["groups"][0]
    check("whole repeated block merged", g["lines"] == 9)
    check("both places reported", g["places"].size() == 2)
    check("comments and spacing ignored", op.analyze({"res://a.gd": "var a = 1\nvar b = 2\nvar c = 3\n", "res://b.gd": "var a  =  1 # x\n\nvar b = 2\n# note\nvar c = 3\n"}, {"min_lines": 3})["summary"]["groups"] == 1)
    check("short blocks below threshold ignored", op.run("res://demo/code_health", {"min_lines": 12})["issues"].is_empty())
    check("trivial-only windows ignored", op.analyze({"res://a.gd": "pass\npass\npass\npass\n", "res://b.gd": "pass\npass\npass\npass\n"}, {"min_lines": 3})["summary"]["groups"] == 0)
    check("duplicates within one file found", op.analyze({"res://a.gd": "x = 1\ny = 2\nz = 3\nq = 0\nx = 1\ny = 2\nz = 3\n"}, {"min_lines": 3})["summary"]["groups"] == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_dup")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/code_health" if true else "")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Duplicate Code Detector TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
