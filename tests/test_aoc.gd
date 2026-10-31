extends SceneTree
const Core := preload("res://addons/a11y_options/core/aoc_coverage.gd")
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
    var result: Dictionary = op.run("res://demo/shipping")
    check("four of seven options evidenced", result["summary"]["found"] == 4)
    check("subtitles found in the options script", str(result["evidence"]["subtitles"]).contains("options_menu.gd"))
    check("colour-blind, mono and hold-toggle missing", op._count(result, "option_not_found") == 3)
    check("custom list replaces defaults", op.analyze({"res://a.gd": "var big_cursor = true"}, {"expect_list": [{"id": "cursor", "patterns": ["big_cursor"]}]})["summary"]["found"] == 1)
    check("bad list rejected", op.run("res://demo/shipping", {"expect": "res://nope.json"})["issues"][0]["kind"] == "bad_input")
    check("missing input is reported", op.run("res://definitely_missing_dir_aoc")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/shipping")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Accessibility Options Coverage TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
