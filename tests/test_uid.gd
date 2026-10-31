extends SceneTree
const Core := preload("res://addons/uid_integrity/core/uid_checker.gd")
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
    var result: Dictionary = op.run("res://demo/uids")
    check("stale ext_resource uid flagged", _has(result, "uid_mismatch", 3))
    check("two declared UIDs found", result["summary"]["declared"] == 2)
    var dup: Dictionary = op.analyze({"res://a.tscn": "[gd_scene format=3 uid=\"uid://same\"]\n", "res://b.tres": "[gd_resource type=\"Resource\" format=3 uid=\"uid://same\"]\n"})
    check("duplicate UID is an error", op._count(dup, "duplicate_uid") == 1)
    var sidecar: Dictionary = op.analyze({"res://icon.png.import": "[remap]\nuid=\"uid://icon1\"\n", "res://x.gd.uid": "uid://script1\n", "res://s.tscn": "[gd_scene format=3]\n[ext_resource type=\"Texture2D\" uid=\"uid://icon1\" path=\"res://icon.png\" id=\"1\"]\n[ext_resource type=\"Script\" uid=\"uid://old\" path=\"res://x.gd\" id=\"2\"]\n"})
    check(".import and .uid sidecars declare UIDs", op._count(sidecar, "uid_mismatch") == 1 and _has(sidecar, "uid_mismatch", 3))
    check("unknown uid in script flagged", op._count(op.analyze({"res://a.gd": "var s = load(\"uid://nowhere\")\n"}), "unknown_uid") == 1)
    check("uid in comment ignored", op.analyze({"res://a.gd": "# uid://nowhere\n"})["issues"].is_empty())
    check("missing input is reported", op.run("res://definitely_missing_dir_uid")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/uids")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Resource UID Integrity Checker TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
