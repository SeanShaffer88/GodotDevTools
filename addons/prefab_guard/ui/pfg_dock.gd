## Smart Prefab and Variant Instance Manager - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/prefab_guard/core/pfg_diff.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Smart Prefab and Variant Instance Manager"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Smart Prefab and Variant Instance Manager"
    title.tooltip_text = "Classify prefab instance overrides, expose drift and generate rollback plans that only --apply ever writes."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Smart Prefab and Variant Instance Manager on this project and list the results below."
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


const HELP_TEXT := "Reads a scene and every prefab it instantiates, then classifies each override honestly: one that now equals the prefab's default is dead weight resisting future edits, and one that differs hides that property from the prefab forever after. The rollback plan is generated as data and nothing is written to a scene unless the CLI runs with explicit --apply, because scene files are source code."


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
    var scene_path := "res://demo/prefabs/room.tscn"
    if not FileAccess.file_exists(scene_path):
        return {"summary": {"instances": 0, "overrides": 0, "dead_overrides": 0, "hiding_overrides": 0, "issues": 1}, "plan": [], "issues": [{"severity": "error", "kind": "missing_file", "path": scene_path, "message": "Scene not found: %s" % scene_path, "fix": "Open a project containing the demo fixtures."}]}
    var scene_text := FileAccess.get_file_as_string(scene_path)
    var prefab_texts: Dictionary = {}
    var ext := op.parse_ext_scenes(scene_text)
    for id in ext:
        var p := str(ext[id])
        if FileAccess.file_exists(p):
            prefab_texts[p] = FileAccess.get_file_as_string(p)
    return op.analyze(scene_text, scene_path, prefab_texts)
