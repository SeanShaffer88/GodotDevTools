extends SceneTree
const Core := preload("res://addons/privacy_audit/core/ppa_auditor.gd")
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
    var result: Dictionary = op.run("res://demo/privacy")
    check("four distinct endpoints", op._count(result, "network_endpoint") == 4)
    check("network classes per file", op._count(result, "network_api") == 3)
    check("unique id flagged", op._count(result, "device_identifier") == 1)
    check("clipboard read found", op._count(result, "clipboard") == 1)
    check("microphone stream found", op._count(result, "microphone") == 1)
    check("external link found", op._count(result, "external_open") == 1)
    check("comments ignored", op.analyze({"res://a.gd": "# OS.get_unique_id()\n"})["issues"].is_empty())
    check("missing input is reported", op.run("res://definitely_missing_dir_ppa")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/privacy")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Privacy and Permissions Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
