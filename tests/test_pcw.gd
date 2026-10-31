extends SceneTree
const Core := preload("res://addons/cleanup_workbench/core/pcw_workbench.gd")
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
    var result: Dictionary = op.run("res://demo/workflow/cleanup")
    check("unused texture listed", result["issues"].any(func(i): return i["kind"] == "unused_candidate" and i["path"].ends_with("unused.png")))
    check("referenced texture not listed", not result["issues"].any(func(i): return i["kind"] == "unused_candidate" and i["path"].ends_with("art/used.png")))
    check("identical copy found", op._count(result, "duplicate_file") == 1)
    check("import for deleted wav is stale", op._count(result, "stale_import") == 1)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gdt_cleanup/empty"))
    check("empty folder found", op._count(op.run("user://gdt_cleanup", {"root": "user://gdt_cleanup"}), "empty_folder") == 1)
    check("UID reference counts as use", op.evaluate({"res://a.png": {"md5": "1", "uid": "uid://abc"}}, "load(\"uid://abc\")")["issues"].is_empty())
    check("missing input is reported", op.run("res://definitely_missing_dir_pcw")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/workflow/cleanup")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Project Cleanup Workbench TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
