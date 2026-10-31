extends SceneTree
const Core := preload("res://addons/mutation_tester/core/gmt_mutator.gd")
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
    var src := FileAccess.get_file_as_string("res://demo/ci/mutation/clamp_health.gd")
    var ms: Array = op.mutants(src)
    check("six operator mutants, return arrow untouched", ms.size() == 6 and not ms.any(func(m): return m["from"] == ">" and m["line"] == 5))
    check("strings and comments not mutated", op.mutants("x = \"a < b\" # c > d\n").is_empty())
    var result: Dictionary = op.run("res://demo/ci/mutation/clamp_health.gd", {"test": "res://demo/ci/mutation/test_clamp_health.gd", "timeout": 30.0})
    check("all six mutants ran", result["summary"]["mutants"] == 6)
    check("boundary mutants survive the weak test", op._count(result, "survived_mutant") == 3)
    check("mutation score 50%", is_equal_approx(float(result["summary"]["score"]), 0.5))
    check("project files untouched", FileAccess.get_file_as_string("res://demo/ci/mutation/clamp_health.gd") == src)
    check("missing input is reported", op.run("res://definitely_missing.gd", {"test": "res://demo/ci/mutation/test_clamp_health.gd"})["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/ci/mutation/clamp_health.gd", {"test": "res://demo/ci/mutation/test_clamp_health.gd"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("GDScript Mutation Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
