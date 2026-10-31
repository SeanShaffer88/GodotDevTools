extends SceneTree
const Core := preload("res://addons/dialogue_vars/core/dvl_lint.gd")
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
    var result: Dictionary = op.run("res://demo/dialogue")
    check("story file read", result["summary"]["files"] == 1)
    check("met_guard and gold read but never set", op._count(result, "read_never_set") == 2)
    check("gold_paid set but never read", op._count(result, "set_never_read") == 1)
    check("external list silences game-set vars", op._count(op.run("res://demo/dialogue", {"external": ["met_guard", "gold"]}), "read_never_set") == 0)
    var mixed: Dictionary = op.analyze({"res://d.json": JSON.stringify({"dialogues": {"x": {"nodes": {"a": {"choices": [{"condition": [{"var": "door", "op": "==", "value": true}], "effects": {"door": "open"}}]}}}}})})
    check("type mismatch noted and list conditions read", op._count(mixed, "type_mismatch") == 1)
    check("non-dialogue JSON ignored", op.analyze({"res://x.json": "{\"a\": 1}"})["summary"]["files"] == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir_dvl")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/dialogue")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Dialogue Variable Lint TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
