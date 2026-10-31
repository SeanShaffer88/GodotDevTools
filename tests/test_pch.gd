extends SceneTree
const Core := preload("res://addons/precommit/core/pch_hook.gd")
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
    var result: Dictionary = op.run("res://demo/suite/precommit.json")
    var hook: String = result["artifacts"]["pre-commit"]
    check("two steps generated", result["summary"]["steps"] == 2)
    check("hook calls each CLI with options", hook.contains("node_paths/cli/npb_cli.gd -- --fail-on=broken_path") and hook.contains("scene_lint/cli/slr_cli.gd"))
    check("hook is marked and POSIX", hook.begins_with("#!/bin/sh\n" + op.MARKER))
    var git := "user://gdt_test_git"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(git).path_join("hooks"))
    var hook_path := ProjectSettings.globalize_path(git).path_join("hooks/pre-commit")
    if FileAccess.file_exists(hook_path):
        DirAccess.remove_absolute(hook_path)
    check("install writes the hook", op.run("res://demo/suite/precommit.json", {"install": true, "git_dir": git})["summary"]["installed"] and FileAccess.file_exists(hook_path))
    check("uninstall removes our hook", op.run("res://demo/suite/precommit.json", {"uninstall": true, "git_dir": git})["summary"]["removed"] and not FileAccess.file_exists(hook_path))
    var f := FileAccess.open(hook_path, FileAccess.WRITE)
    f.store_string("#!/bin/sh\necho mine\n")
    f.close()
    check("foreign hook never overwritten", op._count(op.run("res://demo/suite/precommit.json", {"install": true, "git_dir": git}), "foreign_hook") == 1 and FileAccess.get_file_as_string(hook_path).contains("echo mine"))
    DirAccess.remove_absolute(hook_path)
    var cfg := FileAccess.open("user://gdt_bad_hook.json", FileAccess.WRITE)
    cfg.store_string("[{\"tool\": \"no_such_tool\"}, {\"tool\": \"../evil\"}]")
    cfg.close()
    check("unknown and path-like tools rejected", op._count(op.run("user://gdt_bad_hook.json"), "unknown_tool") == 2)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_config")
    var r: Dictionary = op.run("res://demo/suite/precommit.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Pre-commit Hook Installer TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
