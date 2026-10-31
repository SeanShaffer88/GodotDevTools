extends SceneTree
const Core := preload("res://addons/patch_delta/core/pde_estimator.gd")
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
    var o := {"new": "res://demo/shipping/builds/v2"}
    var result: Dictionary = op.run("res://demo/shipping/builds/v1", o)
    check("one added, one removed, one changed", result["summary"]["added"] == 1 and result["summary"]["removed"] == 1 and result["summary"]["changed"] == 1)
    check("same-size pack detected as changed by hash", result["changed"][0]["path"] == "game.pck")
    check("delta counts changed + added bytes", result["summary"]["delta_bytes"] == 51300)
    check("monolithic pack noted", op._count(result, "monolithic_pack") == 1)
    check("budget enforced", op._count(op.run("res://demo/shipping/builds/v1", {"new": "res://demo/shipping/builds/v2", "max_delta": 10000}), "delta_budget") == 1)
    check("identical builds have no delta", op.evaluate({"a": {"size": 1, "md5": "x"}}, {"a": {"size": 1, "md5": "x"}})["summary"]["delta_bytes"] == 0)
    check("missing input is reported", op.run("res://definitely_missing_build", {"new": "res://demo/shipping/builds/v2"})["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/shipping/builds/v1", {"new": "res://demo/shipping/builds/v2"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Patch Delta Estimator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
