extends SceneTree
const Core := preload("res://addons/script_complexity/core/scx_reporter.gd")
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
    var fns: Array = op.functions(FileAccess.get_file_as_string("res://demo/code_health/player.gd"))
    var choose: Dictionary = fns.filter(func(f): return f["name"] == "choose_action")[0]
    check("choose_action complexity counted", choose["complexity"] == 13)
    check("choose_action nesting counted", choose["nesting"] == 6)
    check("simple function stays at 1", fns.filter(func(f): return f["name"] == "_on_died")[0]["complexity"] == 1)
    var result: Dictionary = op.run("res://demo/code_health")
    check("complex function flagged", _has(result, "complex_function", 34))
    check("deep nesting flagged", _has(result, "deep_nesting", 34))
    check("functions ranked most complex first", result["functions"][0]["name"] == "choose_action")
    check("thresholds configurable", op.run("res://demo/code_health", {"max_complexity": 50, "max_nesting": 9})["issues"].is_empty())
    var m: Array = op.functions("func f(x):\n\tmatch x:\n\t\t1:\n\t\t\tpass\n\t\t2:\n\t\t\tpass\n\t\t_:\n\t\t\tpass\n")
    check("match arms add complexity", m[0]["complexity"] == 4)
    check("long function flagged", _has(op.run("res://demo/code_health", {"max_lines": 5}), "long_function", 34))
    check("missing input is reported", op.run("res://definitely_missing_dir_scx")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/code_health" if true else "")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Script Complexity Reporter TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
