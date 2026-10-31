extends SceneTree
const Scanner := preload("res://addons/release_guard/core/rg_scanner.gd")
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _init() -> void:
    var op = Scanner.new()
    var result: Dictionary = op.run("res://demo/release_guard")
    check("fixture scanned", result["summary"]["files"] == 1)
    check("placeholder reported", result["issues"].size() == 1 and result["issues"][0]["kind"] == "placeholder")
    check("line number reported", result["issues"][0]["line"] == 2)
    var clean: Dictionary = op.analyze({"res://clean.gd": "extends Node\n"})
    check("clean input has no issues", clean["issues"].is_empty())
    var custom: Dictionary = op.analyze({"res://a.txt": "ship me"}, [{"marker": "ship me", "kind": "custom"}])
    check("custom marker supported", custom["issues"].size() == 1 and custom["issues"][0]["kind"] == "custom")
    var missing: Dictionary = op.run("res://definitely_missing_release_guard_directory")
    check("missing directory is an error", missing["issues"][0]["kind"] == "scan_error")
    check("unreadable file is an error", op.analyze({"res://a.txt": null})["issues"][0]["kind"] == "scan_error")
    check("markdown contains marker", op.to_markdown(result).contains("placeholder"))
    check("json parses", JSON.parse_string(op.to_json(result)).has("issues"))
    print("Release Guard TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
