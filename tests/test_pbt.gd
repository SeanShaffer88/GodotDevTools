extends SceneTree
const Core := preload("res://addons/property_tests/core/pbt_tester.gd")
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
    var result: Dictionary = op.run("res://demo/testing/props/spec.json")
    var rows := {}
    for r in result["functions"]:
        rows[r["function"]] = r
    check("two functions tested", result["summary"]["functions"] == 2)
    check("wrap_degrees fails", not rows["wrap_degrees"]["passed"] and op._count(result, "property_failed") == 1)
    check("counterexample shrunk to -1", rows["wrap_degrees"]["counterexample"] == [-1])
    check("clamp_hp holds over every case", rows["clamp_hp"]["passed"] and rows["clamp_hp"]["cases"] == 200)
    check("same seed, same verdict", op.run("res://demo/testing/props/spec.json")["functions"][0]["counterexample"] == [-1])
    check("bad property expression reported", op.evaluate({"script": "res://demo/testing/props/angles.gd", "tests": [{"function": "clamp_hp", "args": [], "properties": ["result >"]}]})["issues"][0]["kind"] == "bad_spec")
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/testing/props/spec.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Property-Based Gameplay Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
