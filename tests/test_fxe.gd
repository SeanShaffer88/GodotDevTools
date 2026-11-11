extends SceneTree
const Engine := preload("res://addons/fix_engine/core/fxe_engine.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
	if ok:
		passes += 1
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)

func _init() -> void:
	var engine = Engine.new()
	var report := {"summary": {"issues": 2}, "issues": [
		{"severity": "warning", "kind": "file_name", "path": "res://demo/fix_engine/BadName.tscn", "line": 0, "message": "bad", "fix": "rename"},
		{"severity": "warning", "kind": "duplicate", "path": "res://demo/fix_engine/dup.png", "line": 0, "message": "dup", "fix": "delete manually"},
	]}
	var result: Dictionary = engine.propose(report)
	check("allowlisted rename proposed", result["fixes"].size() == 1 and str(result["fixes"][0]["to"]) == "bad_name.tscn")
	check("non-allowlisted kind is no_safe_fix", str(result["issues"]).contains("no_safe_fix"))
	check("preview lists the rename", engine.preview(result["fixes"]).contains("BadName.tscn"))
	check("missing report is bad_input", str(engine.run("res://missing_report.json", {})["issues"]).contains("bad_input"))
	check("fixture report proposes a fix", engine.run("res://demo/fix_engine/report.json", {})["fixes"].size() == 1)
	check("markdown lists fixes", engine.to_markdown(result).contains("bad_name.tscn"))
	check("json round-trips", JSON.parse_string(engine.to_json(result)).has("fixes"))
	print("Fix Engine TESTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
