extends SceneTree
const Core := preload("res://addons/offline_harness/core/ocn_harness.gd")
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
    var result: Dictionary = op.run("res://demo/privacy", {"profile": "res://demo/privacy/profile_offline.json"})
    check("scene node and code-created request lack timeouts", op._count(result, "no_timeout") == 2)
    check("score handler ignores failures", op._count(result, "unhandled_result") == 1 and _has(result, "unhandled_result", 11))
    check("checked news handler passes", not _has(result, "unhandled_result", 24))
    var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://demo/privacy/profile_offline.json"))
    check("scores always offline", range(10).all(func(i): return op.decide(profile, "https://api.example.com/scores", i)["fault"] == "offline"))
    check("decisions repeat per seed", op.decide(profile, "https://api.example.com/news", 3) == op.decide(profile, "https://api.example.com/news", 3))
    var news: Array = range(200).map(func(i): return op.decide(profile, "https://api.example.com/news", i)["fault"])
    check("news times out about half the time", news.count("timeout") > 70 and news.count("timeout") < 130)
    check("preview lists found URLs", result["preview"].size() == 4)
    var node = preload("res://addons/offline_harness/runtime/ocn_http.gd").new()
    node.profile = profile
    check("runtime node uses the same decisions", node.peek("https://api.example.com/scores")["fault"] == "offline")
    node.free()
    check("unknown fault rejected", op.analyze({}, {"profile_data": {"rules": [{"fault": "meteor"}]}})["issues"][0]["kind"] == "bad_profile")
    check("missing input is reported", op.run("res://definitely_missing_dir_ocn")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/privacy")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Offline and Poor-Connection Test Harness TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
