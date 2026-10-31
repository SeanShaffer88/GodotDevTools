extends SceneTree
const Core := preload("res://addons/crash_packager/core/crp_packager.gd")
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
    var result: Dictionary = op.run("res://demo/testing/crash/godot.log", {"steps": "res://demo/testing/crash/steps.txt"})
    var log_text: String = result["artifacts"]["log_redacted.txt"]
    check("email, IP, token and two home paths redacted", result["summary"]["redactions"] == 5)
    check("no personal data left", not log_text.contains("alice") and not log_text.contains("192.168") and not log_text.contains("AbCdEf") and not log_text.contains("Bob"))
    check("structure kept", log_text.contains("SCRIPT ERROR") and log_text.contains("<user>"))
    check("system details included", JSON.parse_string(result["artifacts"]["system.json"]).has("godot"))
    check("steps included", result["artifacts"]["steps.txt"].contains("Hit the first enemy"))
    var zipped: Dictionary = op.run("res://demo/testing/crash/godot.log", {"zip": "user://gdt_bug_report.zip"})
    var reader := ZIPReader.new()
    check("zip written with all files", reader.open("user://gdt_bug_report.zip") == OK and reader.get_files().size() == 4)
    check("truncation noted", op._count(op.evaluate("x".repeat(5000), "", {}, {"max_log_bytes": 1024}), "log_truncated") == 1)
    check("missing input is reported", op.run("res://definitely_missing.log")["issues"].any(func(i): return i["kind"] == "missing_log"))
    var r: Dictionary = op.run("res://demo/testing/crash/godot.log", {"steps": "res://demo/testing/crash/steps.txt"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Crash and Error Reproduction Packager TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
