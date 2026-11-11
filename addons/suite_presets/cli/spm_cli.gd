extends SceneTree
## Headless runner for Suite Presets. Preview by default; --apply rewrites project.godot.
## Exit 2 when a --fail-on kind is found; 1 for bad arguments or write failure; otherwise 0.
const Core := preload("res://addons/suite_presets/core/spm_presets.gd")
const KINDS := ["unknown_preset"]
const INPUT_ERRORS := ["scan_error", "bad_input", "unknown_preset"]

func _init() -> void:
	var preset := "full"
	var project := "res://project.godot"
	var out := "res://reports/suite_presets"
	var apply := false
	var fail_on: Array = []
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0)
		var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
		if key == "--preset":
			preset = value
		elif key == "--project":
			project = value
		elif key == "--out":
			out = value
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
	var result: Dictionary = op.run(preset, {})
	if apply and FileAccess.file_exists(project):
		var text := FileAccess.get_file_as_string(project)
		var backup := project + ".bak"
		var bf := FileAccess.open(backup, FileAccess.WRITE)
		if bf != null:
			bf.store_string(text)
			bf.close()
		var f := FileAccess.open(project, FileAccess.WRITE)
		if f == null:
			printerr("Cannot write project file: ", project)
			quit(1)
			return
		f.store_string(op.apply_preset(text, preset, result.get("enabled", []) + result.get("disabled", [])))
		f.close()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
		printerr("Cannot create report directory: ", out)
		quit(1)
		return
	for pair in [["suite_presets.json", op.to_json(result)], ["suite_presets.md", op.to_markdown(result)]]:
		var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
		if file == null:
			printerr("Cannot write report: ", out.path_join(pair[0]))
			quit(1)
			return
		file.store_string(pair[1])
	print("Suite Presets: ", result["summary"])
	var failed := false
	var input_error := false
	for issue in result["issues"]:
		print("[%s] %s:%s %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"]])
		if issue["kind"] in INPUT_ERRORS:
			input_error = true
		if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
			failed = true
	quit(1 if input_error else (2 if failed else 0))
