extends SceneTree
const Core := preload("res://addons/flaky_tests/core/flk_detector.gd")
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
    var result: Dictionary = op.run("res://demo/ci/junit")
    check("four runs, four tests with outcomes", result["summary"]["runs"] == 4 and result["summary"]["tests"] == 4)
    check("network test flaky on the same commit", op._count(result, "flaky_same_commit") == 1 and result["issues"].any(func(i): return i["path"] == "suite.test_net"))
    check("ui test always fails", op._count(result, "always_failing") == 1)
    check("stable save test quiet", not result["issues"].any(func(i): return i["path"] == "suite.test_save"))
    check("JUnit commit property read", op.parse_junit(FileAccess.get_file_as_bytes("res://demo/ci/junit/run3.xml"))["commit"] == "def456")
    var flips: Dictionary = op.evaluate([{"results": {"t": "pass"}}, {"results": {"t": "fail"}}, {"results": {"t": "pass"}}])
    check("flip rate without commits", op._count(flips, "high_flip_rate") == 1)
    check("missing input is reported", op.run("res://definitely_missing_runs")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/ci/junit")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Flaky Test Detector TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
