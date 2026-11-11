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
			var suggested := _suggested_name(kind, base)
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

## Apply only derived renames within root. Existing targets and backups are
## never intentionally overwritten. Files are copied as bytes and verified by
## SHA-256; directories are recursively backed up, including hidden files.
## Symlinks are refused rather than followed outside the allowed root.
func apply_fixes(fixes: Array, root: String = "res://", backup_dir: String = "res://reports/fix_engine/backup") -> Dictionary:
	var applied: Array = []
	var issues: Array = []
	if not root.is_absolute_path() or not backup_dir.is_absolute_path():
		return _fail(root, "Root and backup directory must be absolute paths.", "Choose a project root and a backup directory inside it.", "bad_input")
	var root_abs := _absolute(root)
	var backup_abs := _absolute(backup_dir)
	if not DirAccess.dir_exists_absolute(root_abs) or not _beneath(backup_abs, root_abs):
		return _fail(backup_dir, "Backup directory must be inside an existing root.", "Choose a backup directory inside the project root.", "bad_input")
	if _has_link(root_abs, backup_abs):
		return _fail(backup_dir, "Backup path contains a symbolic link.", "Choose a backup path without symbolic links.", "bad_input")
	for f in fixes:
		if typeof(f) != TYPE_DICTIONARY:
			issues.append(_apply_error("", "Invalid fix entry."))
			continue
		var src := str(f.get("path", ""))
		var kind := str(f.get("kind", ""))
		var target_name := str(f.get("to", ""))
		if not src.is_absolute_path() or kind not in SAFE_KINDS:
			issues.append(_apply_error(src, "Only absolute paths and allowlisted naming fixes are accepted."))
			continue
		var src_abs := _absolute(src)
		var base := src_abs.get_file()
		if not _beneath(src_abs, root_abs) or target_name != _suggested_name(kind, base) or target_name == base or not target_name.is_valid_filename() or target_name in ["", ".", ".."]:
			issues.append(_apply_error(src, "Path or destination is outside the allowed rename scope."))
			continue
		var relative := src_abs.substr((root_abs if root_abs.ends_with("/") else root_abs + "/").length())
		if ".git" in relative.split("/") or ".godot" in relative.split("/") or _beneath(backup_abs, src_abs) or _beneath(src_abs, backup_abs) or _has_link(root_abs, src_abs):
			issues.append(_apply_error(src, "Source overlaps a protected path or contains a symbolic link."))
			continue
		var is_dir := DirAccess.dir_exists_absolute(src_abs)
		if (kind == "directory_name" and not is_dir) or (kind == "file_name" and (is_dir or not FileAccess.file_exists(src_abs))):
			issues.append(_apply_error(src, "Source does not exist or does not match the fix kind."))
			continue
		var dst := src_abs.get_base_dir().path_join(target_name)
		var backup := backup_abs.path_join(relative + ".bak")
		if _exists(dst) or _exists(backup) or _has_link(root_abs, dst) or _has_link(root_abs, backup):
			issues.append(_apply_error(src, "Destination or backup already exists, or backup path contains a symbolic link."))
			continue
		if DirAccess.make_dir_recursive_absolute(backup.get_base_dir()) != OK:
			issues.append(_apply_error(src, "Cannot create backup directory."))
			continue
		var backup_status := _copy_tree(src_abs, backup) if is_dir else _copy_file(src_abs, backup)
		if backup_status != OK:
			issues.append(_apply_error(src, "Backup failed; source was not renamed. A partial backup may need removal."))
			continue
		# Recheck the target immediately before the rename to avoid replacing an
		# existing project file. Concurrent external changes remain a limitation.
		if _exists(dst) or _has_link(root_abs, dst) or DirAccess.rename_absolute(src_abs, dst) != OK:
			issues.append(_apply_error(src, "Destination appeared or rename failed; backup was retained."))
			continue
		applied.append({"from": src, "to": dst, "backup": backup})
	return _finish({"applied": applied.size()}, issues, {"applied": applied})


func _suggested_name(kind: String, base: String) -> String:
	if kind == "directory_name":
		return base.to_snake_case()
	var ext := base.get_extension()
	return base.get_basename().to_snake_case() + ("." + ext if ext != "" else "")


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path().trim_suffix("/")


func _beneath(path: String, root: String) -> bool:
	var prefix := root if root.ends_with("/") else root + "/"
	return path.begins_with(prefix)


func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


func _has_link(root: String, path: String) -> bool:
	var prefix := root if root.ends_with("/") else root + "/"
	if not path.begins_with(prefix):
		return true
	var current := root
	for part in path.substr(prefix.length()).split("/", false):
		var parent := DirAccess.open(current)
		if parent == null:
			break # Later components do not exist yet.
		if parent.is_link(part):
			return true
		current = current.path_join(part)
	return false


func _copy_file(src: String, dst: String) -> int:
	var checksum := FileAccess.get_sha256(src)
	if checksum == "":
		return ERR_CANT_OPEN
	var err := DirAccess.copy_absolute(src, dst)
	if err != OK:
		return err
	return OK if FileAccess.get_sha256(dst) == checksum else ERR_FILE_CORRUPT


func _copy_tree(src: String, dst: String) -> int:
	var dir := DirAccess.open(src)
	if dir == null:
		return ERR_CANT_OPEN
	var err := DirAccess.make_dir_recursive_absolute(dst)
	if err != OK:
		return err
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.is_link(name):
			dir.list_dir_end()
			return ERR_UNAVAILABLE
		var child_src := src.path_join(name)
		var child_dst := dst.path_join(name)
		err = _copy_tree(child_src, child_dst) if dir.current_is_dir() else _copy_file(child_src, child_dst)
		if err != OK:
			dir.list_dir_end()
			return err
		name = dir.get_next()
	dir.list_dir_end()
	return OK


func _apply_error(path: String, message: String) -> Dictionary:
	return _issue("error", "apply_failed", path, 0, message, "Review the path, destination and backup; nothing was renamed for this entry.")

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
