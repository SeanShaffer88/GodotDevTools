extends SceneTree
## Headless runner for Fix Engine. Preview by default; --apply writes backups then renames.
## Exit 2 when a --fail-on kind is found; 1 for bad arguments or write failure; otherwise 0.
const Core := preload("res://addons/fix_engine/core/fxe_engine.gd")
const KINDS := ["no_safe_fix", "apply_failed"]
const INPUT_ERRORS := ["scan_error", "bad_input"]

func _init() -> void:
	var report := ""
	var out := "res://reports/fix_engine"
	var backup := "res://reports/fix_engine/backup"
	var apply := false
	var fail_on: Array = []
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0)
		var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
		if key == "--report":
			report = value
		elif key == "--out":
			out = value
		elif key == "--backup-dir":
			backup = value
		elif key == "--apply":
			apply = true
		elif key == "--fail-on":
			fail_on = Array(value.split(",", false))
		else:
			printerr("Unknown argument: ", arg)
			quit(1)
			return
	for kind in fail_on:
		if kind not in KINDS and kind not in ["issues", "errors"]:
			printerr("Unknown --fail-on kind: %s" % kind)
			quit(1)
			return
	var op = Core.new()
	var result: Dictionary = op.run(report, {})
	if apply and not result.get("fixes", []).is_empty():
		var applied: Dictionary = op.apply_fixes(result["fixes"], "res://", backup)
		result["applied"] = applied.get("applied", [])
		for issue in applied["issues"]:
			result["issues"].append(issue)
		result["summary"]["applied"] = result["applied"].size()
		result["summary"]["issues"] = result["issues"].size()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
		printerr("Cannot create report directory: ", out)
		quit(1)
		return
	for pair in [["fix_engine.json", op.to_json(result)], ["fix_engine.md", op.to_markdown(result)]]:
		var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
		if file == null:
			printerr("Cannot write report: ", out.path_join(pair[0]))
			quit(1)
			return
		file.store_string(pair[1])
	print("Fix Engine: ", result["summary"], " preview: ", op.preview(result.get("fixes", [])))
	var failed := false
	var input_error := false
	var apply_error := false
	for issue in result["issues"]:
		print("[%s] %s:%s %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"]])
		if issue["kind"] in INPUT_ERRORS:
			input_error = true
		if issue["kind"] == "apply_failed":
			apply_error = true
		if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
			failed = true
	quit(1 if input_error else (2 if failed else (1 if apply_error else 0)))
