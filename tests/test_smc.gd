extends SceneTree
const Core := preload("res://addons/merge_conflicts/core/smc_assistant.gd")
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
    var result: Dictionary = op.run("res://demo/workflow/conflicts")
    check("one file with three hunks", result["summary"]["conflicted_files"] == 1 and result["summary"]["hunks"] == 3)
    check("load_steps conflict is trivial", op._count(result, "trivial_conflict") == 1)
    check("ext_resource id reused for different files", op._count(result, "id_collision") == 1 and result["issues"].any(func(i): return i["message"].contains("2_door")))
    check("door position clash named with its node", op._count(result, "property_conflict") == 1 and result["issues"].any(func(i): return i["kind"] == "property_conflict" and i["message"].contains("Door") and i["message"].contains("position")))
    check("clean files ignored", op.analyze({"res://a.tscn": "[gd_scene format=3]\n"})["summary"]["conflicted_files"] == 0)
    check("structural conflict fallback", op._count(op.analyze({"res://b.tscn": "[node name=\"A\" type=\"Node\"]\n<<<<<<< HEAD\n[node name=\"B\" type=\"Node\" parent=\".\"]\n=======\n>>>>>>> x\n"}), "structural_conflict") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_smc")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/workflow/conflicts")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Scene Merge Conflict Assistant TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
