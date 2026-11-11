## Coverage Gate - GDScript coverage estimate from test evidence.
## Godot has no built-in line coverage, so this is an honest ESTIMATE:
## a core function counts as covered when a test file mentions its name
## as a complete identifier. This is not evidence that the function executed.
## Never present the number as measured line coverage. See README.
extends RefCounted

func run(input: String = "res://demo/coverage_gate", options: Dictionary = {}) -> Dictionary:
	var files := {}
	var dir := DirAccess.open(input)
	if dir == null:
		return _fail(input, "Cannot open scan directory.", "Pass --dir=<folder with .gd files>.", "bad_input")
	_collect(input, files)
	var tests: Dictionary = options.get("tests", {})
	if tests.is_empty():
		tests = _collect_tests(str(options.get("tests_dir", "res://tests")))
	return analyze(files, tests, options)

func analyze(files: Dictionary, tests: Dictionary, options: Dictionary = {}) -> Dictionary:
	var issues: Array = []
	var total_funcs := 0
	var covered_funcs := 0
	var per_file := {}
	# Index complete identifiers once; a file stem or a substring of another
	# identifier is not evidence that an individual function is mentioned.
	var test_identifiers := {}
	var identifier_re := RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	for t in tests.values():
		for token in identifier_re.search_all(str(t)):
			test_identifiers[token.get_string()] = true
	var paths: Array = files.keys()
	paths.sort()
	for path in paths:
		var text := str(files[path])
		var funcs: Array = []
		for line in text.split("\n"):
			var s := line.strip_edges()
			if s.begins_with("func "):
				var fname := s.trim_prefix("func ").split("(")[0].strip_edges()
				if fname != "":
					funcs.append(fname)
		var covered := 0
		for f in funcs:
			if test_identifiers.has(f):
				covered += 1
		total_funcs += funcs.size()
		covered_funcs += covered
		per_file[path] = {"functions": funcs.size(), "covered": covered}
	var percent := 0.0
	if total_funcs > 0:
		percent = 100.0 * float(covered_funcs) / float(total_funcs)
	var min_percent := float(options.get("min_percent", 0.0))
	if percent < min_percent:
		issues.append(_issue("warning", "below_threshold", "res://", 0, "Estimated coverage %.1f%% is below %.1f%%." % [percent, min_percent], "Add test checks for uncovered functions, or lower --min-percent."))
	return _finish({"files": paths.size(), "functions": total_funcs, "covered": covered_funcs, "percent": round(percent * 10.0) / 10.0, "min_percent": min_percent}, issues, {"per_file": per_file, "estimate": true})

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
			elif name.ends_with(".gd"):
				out[child] = FileAccess.get_file_as_string(child)
		name = dir.get_next()
	dir.list_dir_end()

func _collect_tests(path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for name in dir.get_files():
		if name.begins_with("test_") and name.ends_with(".gd"):
			var p := path.path_join(name)
			out[p] = FileAccess.get_file_as_string(p)
	return out

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
	var lines: Array = ["# Coverage Gate (estimate)", "", "Summary: " + str(result["summary"]), "", "This is a function-name evidence estimate, not measured line coverage."]
	lines.append("## Findings")
	for issue in result["issues"]:
		lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
	return "\n".join(lines) + "\n"
