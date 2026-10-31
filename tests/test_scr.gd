extends SceneTree
const Core := preload("res://addons/save_corruption/core/scr_tester.gd")
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
    var naive: Dictionary = op.run("res://demo/testing/saves/sample.json", {"loader": "res://demo/testing/saves/naive_loader.gd"})
    check("variants generated per key", naive["summary"]["variants"] == 6 + 2 * 4 + 2)
    check("wrong types accepted by the naive loader", op._count(naive, "accepted_invalid") >= 3)
    check("garbage gives no fallback", op._count(naive, "no_fallback") >= 3)
    check("array root returned as-is", op._count(naive, "bad_return") == 1)
    var robust: Dictionary = op.run("res://demo/testing/saves/sample.json", {"loader": "res://demo/testing/saves/robust_loader.gd"})
    check("robust loader handles every variant", robust["issues"].is_empty() and robust["summary"]["handled"] == robust["summary"]["variants"])
    check("null may be allowed", op.run("res://demo/testing/saves/sample.json", {"loader": "res://demo/testing/saves/naive_loader.gd", "allow_null": true})["issues"].filter(func(i): return i["kind"] == "no_fallback").is_empty())
    check("missing input is reported", op.run("res://definitely_missing.json", {"loader": "res://demo/testing/saves/robust_loader.gd"})["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/testing/saves/sample.json", {"loader": "res://demo/testing/saves/naive_loader.gd"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Save Corruption and Recovery Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
