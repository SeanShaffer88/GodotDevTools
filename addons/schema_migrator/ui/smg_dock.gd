## Hot-Reloadable Schema and Save-Game Migrator - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/schema_migrator/core/smg_registry.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Hot-Reloadable Schema and Save-Game Migrator"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Hot-Reloadable Schema and Save-Game Migrator"
    title.tooltip_text = "Version save games and migrate old saves forward with registered rename, move, default and delete ops."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Hot-Reloadable Schema and Save-Game Migrator on this project and list the results below."
    run_btn.pressed.connect(_on_run)
    add_child(run_btn)
    var help_btn := Button.new()
    help_btn.text = "?"
    help_btn.tooltip_text = "Show plain-words help for this tool."
    help_btn.pressed.connect(func() -> void: _results.text = HELP_TEXT)
    add_child(help_btn)
    _results = RichTextLabel.new()
    _results.fit_content = true
    _results.custom_minimum_size = Vector2(320, 300)
    _results.tooltip_text = "Results of the last run. Run the check to fill this in."
    add_child(_results)
    _results.text = "Press Run check."


const HELP_TEXT := "Save files carry a schema_version and the registry JSON lists each version's required fields plus the migration steps between versions: rename, move, default and delete ops. Every run re-reads the registry from disk, so you can edit the schema file and migrate again without restarting anything - that is the hot-reload story. The report shows the version path taken, the ops applied, and any save the registry cannot carry forward."


func _json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _on_run() -> void:
    var result: Dictionary = _run_check()
    var lines: Array[String] = []
    var s: Dictionary = result.get("summary", {})
    lines.append("Summary: " + str(s))
    var issues: Array = result.get("issues", [])
    if issues.is_empty():
        lines.append("No problems found.")
    for i in issues:
        lines.append("[%s] %s" % [i.get("severity", "info"), i.get("message", "")])
        if i.get("fix", "") != "":
            lines.append("  Fix: " + str(i["fix"]))
    for key in ["trace", "plan", "specs", "remap_menu", "applied_steps"]:
        var extra: Array = result.get(key, [])
        var shown := 0
        for row in extra:
            if shown >= 40:
                lines.append("... %d more %s row(s)" % [extra.size() - 40, key])
                break
            lines.append("%s: %s" % [key, str(row)])
            shown += 1
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Core.new()
    var loaded := op.load_registry("res://demo/schema/player_schema.json")
    if not (loaded["errors"] as Array).is_empty():
        return {"summary": {"from": 0, "to": 0, "applied": 0, "issues": (loaded["errors"] as Array).size()}, "issues": loaded["errors"]}
    var save_path := "res://demo/schema/old_save.json"
    if not FileAccess.file_exists(save_path):
        return {"summary": {"from": 0, "to": 0, "applied": 0, "issues": 1}, "issues": [{"severity": "error", "kind": "missing_file", "path": save_path, "message": "Save file not found: %s" % save_path, "fix": "Point the dock at a real save file."}]}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return {"summary": {"from": 0, "to": 0, "applied": 0, "issues": 1}, "issues": [{"severity": "error", "kind": "bad_json", "path": save_path, "message": "Save file is not a JSON object: %s" % save_path, "fix": "Repair the save file."}]}
    return op.migrate(parsed)
