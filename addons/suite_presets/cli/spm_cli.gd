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
	if not FileAccess.file_exists(project):
		printerr("Project file not found: ", project)
		quit(1)
		return
	var addons_dir := project.get_base_dir().path_join("addons")
	if DirAccess.open(addons_dir) == null:
		printerr("Cannot enumerate the target project's addons: ", addons_dir)
		quit(1)
		return
	var op = Core.new()
	var result: Dictionary = op.run(preset, {"addons_dir": addons_dir})
	if apply and result["issues"].is_empty():
		var parent := DirAccess.open(project.get_base_dir())
		var backup := project + ".bak"
		if parent == null or parent.is_link(project.get_file()) or parent.is_link(backup.get_file()):
			printerr("Project or backup is a symbolic link, or its directory is inaccessible.")
			quit(1)
			return
		var bytes := FileAccess.get_file_as_bytes(project)
		var text := bytes.get_string_from_utf8()
		if text.to_utf8_buffer() != bytes:
			printerr("Project file is not valid UTF-8; it was not changed.")
			quit(1)
			return
		var transform: Dictionary = op.rewrite_preset(text, preset, result.get("enabled", []) + result.get("disabled", []))
		if not transform["ok"]:
			printerr("Cannot safely rewrite project.godot: ", transform["error"])
			quit(1)
			return
		var rewritten: String = transform["text"]
		if rewritten != text:
			if FileAccess.file_exists(backup) or DirAccess.dir_exists_absolute(backup):
				printerr("Backup already exists; move it before applying: ", backup)
				quit(1)
				return
			var hash := FileAccess.get_sha256(project)
			if hash == "" or DirAccess.copy_absolute(ProjectSettings.globalize_path(project), ProjectSettings.globalize_path(backup)) != OK or FileAccess.get_sha256(backup) != hash:
				printerr("Could not create a verified backup; project was not changed: ", backup)
				quit(1)
				return
			var f := FileAccess.open(project, FileAccess.WRITE)
			if f == null:
				printerr("Cannot write project file: ", project, "; backup retained at ", backup)
				quit(1)
				return
			f.store_string(rewritten)
			var write_error := f.get_error()
			f.close()
			if write_error != OK:
				printerr("Project write failed; restore backup: ", backup)
				quit(1)
				return
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
