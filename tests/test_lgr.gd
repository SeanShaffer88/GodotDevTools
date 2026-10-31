extends SceneTree
const Core := preload("res://addons/log_grouper/core/lgr_grouper.gd")
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
    var result: Dictionary = op.run("res://demo/ci/logs/run.log")
    check("five error events in two groups", result["summary"]["errors"] == 5 and op._count(result, "error_group") == 2)
    check("three warnings in two groups", result["summary"]["warnings"] == 3 and op._count(result, "warning_group") == 2)
    check("most frequent group first", result["groups"][0]["count"] == 3 and result["groups"][0]["signature"].begins_with("SCRIPT ERROR"))
    check("names and numbers masked", op.normalize("WARNING: Texture 'res://a_1.png' is larger than 4096 px.") == "WARNING: Texture '<str>' is larger than N px.")
    check("location captured", result["groups"][0]["location"].contains("enemy.gd"))
    check("plain lines ignored", op.evaluate("hello\nLevel loaded in 5 ms\n")["summary"]["groups"] == 0)
    check("missing input is reported", op.run("res://definitely_missing.log")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/ci/logs/run.log")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Error Log Grouper TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
