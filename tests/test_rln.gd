extends SceneTree
const Core := preload("res://addons/release_notes/core/rln_generator.gd")
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
    var result: Dictionary = op.run("res://demo/shipping/commits.txt")
    check("two fixes, one feature, one perf", result["summary"]["Fixed"] == 2 and result["summary"]["Added"] == 1 and result["summary"]["Performance"] == 1)
    check("breaking change separated", result["summary"]["Breaking"] == 1 and op._count(result, "breaking_change") == 1)
    check("merge skipped, one nonconventional", op._count(result, "nonconventional_commit") == 1)
    check("scopes shown in bold", result["notes"].contains("**ui:** add pause menu remapping"))
    check("other hidden by default", not result["notes"].contains("### Other"))
    check("other shown on request", op.run("res://demo/shipping/commits.txt", {"include_other": true})["notes"].contains("update README"))
    check("missing input is reported", op.run("res://definitely_missing.txt")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/shipping/commits.txt")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Release Notes Generator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
