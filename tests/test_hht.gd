extends SceneTree
const Core := preload("res://addons/hitbox_timeline/core/hht_timeline.gd")
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
    var result: Dictionary = op.run("res://demo/runtime_perf")
    var hit: Dictionary = result["timelines"].filter(func(t): return t["node"] == "Hitbox/Shape")[0]
    check("four tracks on the timeline", result["summary"]["timelines"] == 4)
    check("hitbox window 0.2-0.35 is 9 frames", hit["windows"].size() == 1 and is_equal_approx(float(hit["windows"][0]["frames"]), 9.0))
    check("sweep left active at the end", op._count(result, "stays_active") == 1)
    check("flash window shorter than a frame", op._count(result, "window_too_short") == 1)
    check("hurtbox invulnerability noted", op._count(result, "invulnerable_window") == 1)
    check("at 120 Hz the flash registers", op._count(op.run("res://demo/runtime_perf", {"physics_fps": 120}), "window_too_short") == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir_hht")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/runtime_perf")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Hitbox and Hurtbox Timeline Viewer TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
