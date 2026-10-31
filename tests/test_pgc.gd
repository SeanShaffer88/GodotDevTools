extends SceneTree
const Core := preload("res://addons/procgen_constraints/core/pgc_tester.gd")
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

func _count_file(result: Dictionary, kind: String, file: String) -> int:
    return result["issues"].filter(func(i): return i["kind"] == kind and str(i["path"]).ends_with(file)).size()

func _init() -> void:
    var result: Dictionary = op.run("res://demo/gameplay/maps")
    check("four maps, two fail", result["summary"]["maps"] == 4 and result["summary"]["failed"] == 2)
    check("walled-off exit found", _count_file(result, "unreachable_exit", "seed_02.map") == 1)
    check("key behind its own door found", _count_file(result, "key_behind_door", "seed_03.map") == 1)
    check("door after key passes", not result["issues"].any(func(i): return i["path"].ends_with("seed_04.map") and i["severity"] == "error"))
    check("pocket detected", op.check_map("#####\n#S.E#\n#####\n#..##\n#####", {"max_dead_end_ratio": 1.0}).any(func(p): return p[1] == "isolated_pocket"))
    check("map without exit rejected", op.check_map("###\n#S#\n###", {"max_dead_end_ratio": 1.0})[0][1] == "bad_map")
    check("missing input is reported", op.run("res://definitely_missing_dir_pgc")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/gameplay/maps")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Procedural Generation Constraint Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
