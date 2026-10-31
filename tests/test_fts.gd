extends SceneTree
const Core := preload("res://addons/frame_spikes/core/fts_investigator.gd")
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
    var result: Dictionary = op.run("res://demo/runtime_perf/frames.json")
    check("two spikes found", result["summary"]["spikes"] == 2)
    check("level load spike blamed on marker and nodes", result["spikes"][0]["causes"].any(func(c): return c.contains("load_level")) and result["spikes"][0]["causes"].any(func(c): return c.contains("+400")))
    check("physics spike blamed on physics", result["spikes"][1]["causes"].any(func(c): return c.contains("physics")))
    check("steady state within budget", op._count(result, "budget_miss_rate") == 0)
    var rec = preload("res://addons/frame_spikes/runtime/fts_recorder.gd").new()
    rec.mark("boss")
    rec.record(16.0, 1.0, 100)
    rec.record(80.0, 1.0, 100)
    rec.record(16.0, 1.0, 100)
    var r2: Dictionary = op.evaluate(rec.log_data())
    check("recorder output feeds the investigator", r2["summary"]["spikes"] == 1 and r2["spikes"][0]["causes"].any(func(c): return c.contains("boss")))
    rec.free()
    check("sustained overload reported", op._count(op.evaluate({"frames": [{"ms": 30}, {"ms": 30}, {"ms": 30}]}), "budget_miss_rate") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/runtime_perf/frames.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Frame-Time Spike Investigator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
