## Cross-Platform Virtual Filesystem tests.
extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0


func _check(label: String, ok: bool, evidence: String = "") -> void:
    if ok:
        _passes += 1
        print("PASS  ", label)
    else:
        _failures.append(label)
        print("FAIL  ", label, "  ", evidence)


func _finish(name: String) -> void:
    print("----")
    print(name, ": %d passed, %d failed" % [_passes, _failures.size()])
    quit(1 if not _failures.is_empty() else 0)


func _kinds(issues: Array) -> Array:
    var out: Array = []
    for i in issues:
        out.append(i["kind"])
    return out

const FS := preload("res://addons/vfs_mock/core/vfm_fs.gd")


func _init() -> void:
    var op = FS.new()
    var files: Array = op.collect_files()
    var case_hit: Array = op.resolve({"op": "read", "path": "res://demo/vfs/SAVE.JSON"}, "linux", files)
    _check("wrong-case read 404s on linux", _kinds(case_hit).has("case_mismatch"), str(case_hit))
    var win_hit: Array = op.resolve({"op": "read", "path": "res://demo/vfs/SAVE.JSON"}, "windows", files)
    _check("windows hides the same wrong-case read", not _kinds(win_hit).has("case_mismatch"), str(win_hit))
    _check("sandbox escape caught", _kinds(op.resolve({"op": "read", "path": "user://../outside.txt"}, "linux", files)).has("sandbox_escape"))
    _check("write into the packed root denied on android", _kinds(op.resolve({"op": "write", "path": "res://saves/slot.dat"}, "android", files)).has("permission_denied"))
    _check("reserved device name caught on windows", _kinds(op.resolve({"op": "write", "path": "user://CON.txt"}, "windows", files)).has("reserved_name"))
    _check("forbidden character caught on windows", _kinds(op.resolve({"op": "write", "path": "user://bad|name.txt"}, "windows", files)).has("forbidden_char"))
    var audit: Array = op.audit_script(FileAccess.get_file_as_string("res://demo/vfs/io_code.gd"), "res://demo/vfs/io_code.gd")
    var audit_kinds := _kinds(audit)
    _check("backslash literal audited", audit_kinds.has("backslash_path"), str(audit))
    _check("drive letter audited", audit_kinds.has("drive_letter"))
    _check("hardcoded climb audited", audit_kinds.has("path_traversal"))
    var r: Dictionary = op.run()
    _check("project self-check flags the case collision (gate kind)", _kinds(r["issues"]).has("case_collision"), str(r["by_kind"]))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Cross-Platform Virtual Filesystem TESTS")
