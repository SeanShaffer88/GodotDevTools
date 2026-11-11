extends SceneTree
const FixEngine := preload("res://addons/fix_engine/core/fxe_engine.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
	if ok:
		passes += 1
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)

func _write_bytes(path: String, data: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(data)
	file.close()
	return true

func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _init() -> void:
	var engine = FixEngine.new()
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

	# Work only in a private user:// directory: test that apply preserves binary
	# bytes, refuses collisions/traversal, and backs up whole directories.
	var root := "user://fix_engine_test_%s" % str(OS.get_process_id())
	var backup := root.path_join("backups")
	check("scratch directory created", DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) == OK)
	var binary := PackedByteArray([0, 255, 128, 10, 1, 0])
	var src := root.path_join("BadIcon.png")
	check("binary fixture written", _write_bytes(src, binary))
	var expected_hash := FileAccess.get_sha256(src)
	var applied: Dictionary = engine.apply_fixes([{"kind": "file_name", "path": src, "to": "bad_icon.png"}], root, backup)
	var renamed := root.path_join("bad_icon.png")
	var saved := backup.path_join("BadIcon.png.bak")
	check("binary file renamed", applied.get("applied", []).size() == 1 and not FileAccess.file_exists(src))
	check("renamed binary and backup are byte-identical", FileAccess.get_sha256(renamed) == expected_hash and FileAccess.get_sha256(saved) == expected_hash)

	var conflict_src := root.path_join("OtherFile.png")
	var conflict_dst := root.path_join("other_file.png")
	_write_bytes(conflict_src, binary)
	_write_bytes(conflict_dst, PackedByteArray([5, 6, 7]))
	var dst_hash := FileAccess.get_sha256(conflict_dst)
	var collision: Dictionary = engine.apply_fixes([{"kind": "file_name", "path": conflict_src, "to": "other_file.png"}], root, backup)
	check("existing destination is not overwritten", not collision["issues"].is_empty() and FileAccess.file_exists(conflict_src) and FileAccess.get_sha256(conflict_dst) == dst_hash)
	var backup_src := root.path_join("ThirdFile.png")
	var existing_backup := backup.path_join("ThirdFile.png.bak")
	_write_bytes(backup_src, binary)
	_write_bytes(existing_backup, PackedByteArray([42]))
	var backup_hash := FileAccess.get_sha256(existing_backup)
	var backup_collision: Dictionary = engine.apply_fixes([{"kind": "file_name", "path": backup_src, "to": "third_file.png"}], root, backup)
	check("existing backup is not overwritten", not backup_collision["issues"].is_empty() and FileAccess.file_exists(backup_src) and FileAccess.get_sha256(existing_backup) == backup_hash)
	var bad_target: Dictionary = engine.apply_fixes([{"kind": "file_name", "path": conflict_src, "to": "../escape.png"}], root, backup)
	check("traversal destination is rejected", not bad_target["issues"].is_empty() and FileAccess.file_exists(conflict_src))
	var outside: Dictionary = engine.apply_fixes([{"kind": "file_name", "path": "user://Outside.png", "to": "outside.png"}], root, backup)
	check("source outside root is rejected", not outside["issues"].is_empty())

	var folder := root.path_join("BadFolder")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_write_bytes(folder.path_join(".hidden.bin"), binary)
	var folder_result: Dictionary = engine.apply_fixes([{"kind": "directory_name", "path": folder, "to": "bad_folder"}], root, backup)
	check("directory rename preserves hidden files and backup", folder_result.get("applied", []).size() == 1 and FileAccess.get_sha256(root.path_join("bad_folder/.hidden.bin")) == expected_hash and FileAccess.get_sha256(backup.path_join("BadFolder.bak/.hidden.bin")) == expected_hash)
	_remove_tree(root)
	print("Fix Engine TESTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
