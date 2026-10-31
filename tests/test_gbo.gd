extends SceneTree
const Core := preload("res://addons/overdraw/core/gbo_analyzer.gd")
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
    var result: Dictionary = op.run("res://demo/perf_static")
    var menu: Dictionary = result["scenes"].filter(func(s): return s["path"].ends_with("menu_bg.tscn"))[0]
    check("five screens of drawing", is_equal_approx(float(menu["overdraw"]), 5.0))
    check("overdraw over budget", op._count(result, "overdraw_budget") == 1)
    check("five full-screen layers", menu["fullscreen_layers"] == 5 and op._count(result, "stacked_fullscreen") == 1)
    check("fill rate at 60 fps", is_equal_approx(float(menu["fill_rate_mpix_s"]), 622.1))
    check("4K screen halves the sprite share", op.run("res://demo/perf_static", {"width": 3840, "height": 2160})["scenes"][0]["overdraw"] < 2.0)
    check("hidden nodes skipped", op.analyze({"res://h.tscn": "[node name=\"R\" type=\"ColorRect\"]\nvisible = false\noffset_right = 1920.0\noffset_bottom = 1080.0\n"})["summary"]["scenes"] == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir_gbo")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/perf_static")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("GPU Budget and Overdraw Analyzer TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
