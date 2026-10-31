extends SceneTree
const Core := preload("res://addons/save_bloat/core/sba_auditor.gd")
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
    var result: Dictionary = op.run("res://demo/balance/saves")
    check("two samples measured", result["summary"]["samples"] == 2)
    check("event log dominates the later save", op._count(result, "key_dominates") == 1)
    check("event log growth flagged", op._count(result, "key_growth") == 1 and result["issues"].any(func(i): return i["message"].begins_with("event_log")))
    check("nested keys measured", result["samples"][0]["keys"].has("player/level"))
    check("default budget not exceeded", op._count(result, "save_over_budget") == 0)
    check("tight budget flags the big save", op._count(op.run("res://demo/balance/saves", {"max_bytes": 10000}), "save_over_budget") == 1)
    check("non-object save rejected", op.analyze({"res://s.json": "[1,2]"})["issues"][0]["kind"] == "bad_input")
    check("missing input is reported", op.run("res://definitely_missing_dir_sba")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/balance/saves")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Save File Bloat Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
