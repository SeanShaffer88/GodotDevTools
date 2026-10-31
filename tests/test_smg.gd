## Schema and Save-Game Migrator tests.
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

const Registry := preload("res://addons/schema_migrator/core/smg_registry.gd")


func _init() -> void:
    var op = Registry.new()
    var loaded := op.load_registry("res://demo/schema/player_schema.json")
    _check("fixture registry loads", (loaded["errors"] as Array).is_empty(), str(loaded["errors"]))
    var mpath: Array = op.migration_path(1, 2)
    _check("migration path 1->2 has one step", mpath.size() == 1, str(mpath))
    _check("migration path 1->3 is unmigratable", op.migration_path(1, 3).is_empty())
    var v1 := {"schema_version": 1, "hp": 80, "pos": {"x": 12, "y": 3}, "legacy_flag": true}
    var to2: Dictionary = op.migrate(v1, 2)
    _check("v1 save migrates cleanly to v2", int(to2["summary"]["issues"]) == 0 and int((to2["data"] as Dictionary).get("health", 0)) == 80, str(to2["summary"]))
    _check("ops applied: legacy_flag deleted, stamina defaulted", not (to2["data"] as Dictionary).has("legacy_flag") and int((to2["data"] as Dictionary).get("stamina", 0)) == 100)
    var fixture_save = JSON.parse_string(FileAccess.get_file_as_string("res://demo/schema/old_save.json"))
    var stuck: Dictionary = op.migrate(fixture_save)
    _check("fixture save cannot reach v3 (gate kind)", _kinds(stuck["issues"]).has("unmigratable"), str(stuck["summary"]))
    op.registry = {"name": "test", "current_version": 3, "fields": {"3": ["inventory"]}, "migrations": [{"from": 2, "to": 3, "ops": []}]}
    var gap: Dictionary = op.migrate({"schema_version": 2, "health": 1})
    _check("missing required field after migration is reported", _kinds(gap["issues"]).has("missing_field"), str(gap["issues"]))
    var bad := op.load_registry("res://demo/schema/nope.json")
    _check("missing registry file is an error", _kinds(bad["errors"]).has("missing_file"))
    _check("to_markdown renders a title", op.to_markdown(stuck).begins_with("# "))
    _finish("Schema and Save-Game Migrator TESTS")
