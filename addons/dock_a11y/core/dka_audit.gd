## Dock Accessibility Audit - dogfoods a11y checks on the docks.
## Text heuristic over ui/*_dock.gd: every interactive control creation
## should be followed by a tooltip_text assignment in the same file, the
## dock should expose _on_run, and output should carry help text.
## This audits the tools themselves, not the user's game.
extends RefCounted

const CONTROLS := ["Button.new", "LineEdit.new", "CheckBox.new", "OptionButton.new", "SpinBox.new", "HSlider.new", "TextEdit.new", "ItemList.new", "Tree.new", "RichTextLabel.new"]

func run(input: String = "res://demo/dock_a11y", options: Dictionary = {}) -> Dictionary:
	var files := {}
	var dir := DirAccess.open(input)
	if dir == null:
		return _fail(input, "Cannot open scan directory.", "Pass --dir=<folder with *_dock.gd files>.", "bad_input")
	_collect(input, files)
	return analyze(files)

func analyze(files: Dictionary) -> Dictionary:
	var issues: Array = []
	var paths: Array = files.keys()
	paths.sort()
	for path in paths:
		var text := str(files[path])
		if not text.contains("_on_run"):
			issues.append(_issue("warning", "missing_run_action", path, 0, "Dock has no _on_run action.", "Add a run button wired to _on_run so the dock does something."))
		if not text.contains("tooltip_text"):
			issues.append(_issue("warning", "missing_tooltip", path, 0, "Dock sets no tooltip_text.", "Give every control a tooltip explaining what it does."))
		if not text.contains("focus_mode") and not text.contains("FOCUS"):
			issues.append(_issue("info", "keyboard_focus_unverified", path, 0, "Dock does not set focus_mode explicitly.", "Confirm Tab order reaches every control; buttons and line edits are focusable by default."))
		for control in CONTROLS:
			if text.contains(control) and not text.contains("tooltip_text"):
				issues.append(_issue("warning", "missing_tooltip", path, 0, "Control %s may lack a tooltip." % control, "Set tooltip_text on the control."))
				break
	return _finish({"files": paths.size()}, issues, {})

func _collect(path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var child := path.path_join(name)
			if dir.current_is_dir():
				_collect(child, out)
			elif name.ends_with("_dock.gd"):
				out[child] = FileAccess.get_file_as_string(child)
		name = dir.get_next()
	dir.list_dir_end()

func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
	return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}

func _fail(path: String, message: String, fix: String, kind: String = "scan_error") -> Dictionary:
	return {"summary": {"issues": 1}, "issues": [_issue("error", kind, path, 0, message, fix)]}

func _finish(summary: Dictionary, issues: Array, extra: Dictionary = {}) -> Dictionary:
	issues.sort_custom(func(a, b): return "%s|%08d|%s" % [a["path"], int(a["line"]), a["kind"]] < "%s|%08d|%s" % [b["path"], int(b["line"]), b["kind"]])
	summary["issues"] = issues.size()
	var result := {"summary": summary, "issues": issues}
	result.merge(extra)
	return result

func to_json(result: Dictionary) -> String:
	return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
	var lines: Array = ["# Dock Accessibility Audit", "", "Summary: " + str(result["summary"]), "", "## Findings"]
	for issue in result["issues"]:
		lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
	return "\n".join(lines) + "\n"
