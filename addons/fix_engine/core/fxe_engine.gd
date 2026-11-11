## Fix Engine - shared, opt-in fix proposer over tool reports.
## Consumes report JSON (report_schema contract); no tool depends on it.
## Default is preview-only. Applying requires --apply in the CLI (or the
## dock checkbox) and always writes a backup copy first. Only allowlisted
## kinds are proposed; everything else is reported as no_safe_fix.
extends RefCounted

const SAFE_KINDS := ["file_name", "directory_name"]

func run(report_path: String = "", options: Dictionary = {}) -> Dictionary:
	var report: Variant = options.get("report", null)
	if report == null:
		if report_path == "" or not FileAccess.file_exists(report_path):
			return _fail(report_path, "Report file not found.", "Pass --report=<tool report JSON> or run a tool CLI first.", "bad_input")
		report = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if typeof(report) != TYPE_DICTIONARY or typeof(report.get("issues")) != TYPE_ARRAY:
		return _fail(report_path, "Report is not a findings report.", "Pass a <tool>.json with summary and issues.", "bad_input")
	return propose(report)

func propose(report: Dictionary) -> Dictionary:
	var fixes: Array = []
	var issues: Array = []
	for issue in report["issues"]:
		var kind := str(issue.get("kind", ""))
		var path := str(issue.get("path", ""))
		if kind in SAFE_KINDS and path != "":
			var base := path.get_file()
			var stem := base.get_basename().to_snake_case()
			var ext := base.get_extension()
			var suggested := stem + ("." + ext if ext != "" else "")
			if suggested != base and suggested != "":
				fixes.append({"kind": kind, "path": path, "from": base, "to": suggested, "message": str(issue.get("message", "")), "fix": str(issue.get("fix", ""))})
			else:
				issues.append(_issue("info", "no_safe_fix", path, 0, "No safe rename can be derived for '%s'." % base, "Rename manually after reviewing references."))
		else:
			issues.append(_issue("info", "no_safe_fix", path, 0, "Kind '%s' has no allowlisted automatic fix." % kind, "Apply the plain-words fix in the original report manually."))
	return _finish({"report_issues": report["issues"].size(), "fixes": fixes.size()}, issues, {"fixes": fixes})

func preview(fixes: Array) -> String:
	var lines: Array = []
	for f in fixes:
		lines.append("rename %s -> %s" % [f["path"], f["to"]])
	return "\n".join(lines)

## Apply renames under root, backing up each file first. Returns applied list.
## Only called when the user explicitly opted in (--apply / dock checkbox).
func apply_fixes(fixes: Array, root: String = "res://", backup_dir: String = "res://reports/fix_engine/backup") -> Dictionary:
	var applied: Array = []
	var issues: Array = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_dir))
	for f in fixes:
		var src := str(f["path"])
		var dst := src.get_base_dir().path_join(str(f["to"]))
		if not FileAccess.file_exists(src):
			issues.append(_issue("warning", "apply_failed", src, 0, "Source file does not exist.", "Check the path and retry."))
			continue
		var backup := backup_dir.path_join(src.get_file() + ".bak")
		var data := FileAccess.get_file_as_string(src)
		var bf := FileAccess.open(backup, FileAccess.WRITE)
		if bf == null:
			issues.append(_issue("error", "apply_failed", src, 0, "Cannot write backup.", "Check backup directory permissions."))
			continue
		bf.store_string(data)
		bf.close()
		if DirAccess.rename_absolute(src, dst) != OK:
			issues.append(_issue("error", "apply_failed", src, 0, "Rename failed.", "Restore from the backup copy."))
			continue
		applied.append({"from": src, "to": dst, "backup": backup})
	return _finish({"applied": applied.size()}, issues, {"applied": applied})

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
	var lines: Array = ["# Fix Engine", "", "Summary: " + str(result["summary"]), "", "## Proposed fixes"]
	for f in result.get("fixes", []):
		lines.append("- rename `%s` -> `%s`" % [f["path"], f["to"]])
	lines.append("## Findings")
	for issue in result["issues"]:
		lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
	return "\n".join(lines) + "\n"
