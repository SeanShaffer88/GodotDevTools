extends SceneTree
const Audit := preload("res://addons/dock_a11y/core/dka_audit.gd")
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
	var audit = Audit.new()
	var good := {"res://demo/dock_a11y/good_dock.gd": "@tool\nextends VBoxContainer\nfunc _on_run() -> void:\n\tpass\nvar b := Button.new()\nb.tooltip_text = \"Run\"\n"}
	var bad := {"res://demo/dock_a11y/bad_dock.gd": "@tool\nextends VBoxContainer\nfunc _init() -> void:\n\tvar b := Button.new()\n"}
	check("good dock has no tooltip finding", not str(audit.analyze(good)["issues"]).contains("missing_tooltip"))
	check("bad dock flagged missing tooltip", str(audit.analyze(bad)["issues"]).contains("missing_tooltip"))
	check("bad dock flagged missing run action", str(audit.analyze(bad)["issues"]).contains("missing_run_action"))
	check("missing dir is bad_input", str(audit.run("res://missing_dka_dir", {})["issues"]).contains("bad_input"))
	var fixture: Dictionary = audit.run("res://demo/dock_a11y", {})
	check("fixture finds both docks", fixture["summary"]["files"] == 2)
	check("fixture flags the bad dock", str(fixture["issues"]).contains("missing_tooltip"))
	check("markdown has findings", audit.to_markdown(fixture).contains("missing_tooltip"))
	check("json round-trips", JSON.parse_string(audit.to_json(fixture)).has("issues"))
	print("Dock Accessibility Audit TESTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
