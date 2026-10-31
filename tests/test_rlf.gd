extends SceneTree
const Core := preload("res://addons/load_failure/core/rlf_simulator.gd")
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
    var result: Dictionary = op.run("res://demo/testing/loads")
    check("dynamic level load used unchecked", _has(result, "unchecked_load", 8))
    check("menu load chained", _has(result, "chained_load", 12))
    check("missing menu path", _has(result, "missing_resource", 12))
    check("checked options load passes", not result["issues"].any(func(i): return i["line"] >= 16 and i["line"] <= 21 and i["kind"] == "unchecked_load"))
    check("threaded load without status", op._count(result, "threaded_no_status") == 1)
    check("preload ignored", op.analyze({"res://a.gd": "const X := preload(\"res://nope.tscn\")\n"})["issues"].is_empty())
    check("missing input is reported", op.run("res://definitely_missing_dir_rlf")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/testing/loads")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Resource Load Failure Simulator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
