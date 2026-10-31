extends SceneTree
const Core := preload("res://addons/anim_audit/core/apa_auditor.gd")
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
    check("one animation with three tracks", result["summary"]["animations"] == 1 and result["summary"]["tracks"] == 3)
    check("constant modulate track", op._count(result, "constant_track") == 1 and result["issues"].any(func(i): return i["message"].contains("Sprite:modulate")))
    check("duplicate key time on position", op._count(result, "duplicate_time_key") == 1)
    check("changing frame track clean", not result["issues"].any(func(i): return i["message"].contains("Sprite:frame")))
    check("values split at top level", op.split_values("[Vector2(0, 1), Color(1, 1, 1, 1), 3]").size() == 3)
    var red := "[gd_resource type=\"Animation\" format=3]\n[resource]\ntracks/0/type = \"value\"\ntracks/0/interp = 1\ntracks/0/keys = {\n\"times\": PackedFloat32Array(0, 1, 2, 3),\n\"values\": [0, 5, 5, 5]\n}\n"
    check("redundant interior key found", op._count(op.analyze({"res://r.tres": red}), "redundant_keys") == 1)
    check("track budget configurable", op._count(op.run("res://demo/perf_static", {"max_tracks": 2}), "track_budget") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_apa")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/perf_static")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Animation Performance Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
