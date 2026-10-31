## Level Whiteboxing and Snapping Suite - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/whitebox/core/wbx_snap.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Level Whiteboxing and Snapping Suite"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Level Whiteboxing and Snapping Suite"
    title.tooltip_text = "Grid snapping and slope maths plus a scene scan for off-grid blockout props and unwalkable ramps."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Level Whiteboxing and Snapping Suite on this project and list the results below."
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


const HELP_TEXT := "The blockout maths and its audit: snap positions to a grid (whole cells or subdivisions), snap rotations to a step, and judge slopes between walk points against your character controller's limit. The scene scan reads Node3D transforms from scene text and reports props floating between cells and ramps too steep to climb, so a blockout stays honest before art arrives. The dock snaps selected nodes in the live editor."


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
    var scene_text := ""
    if FileAccess.file_exists("res://demo/whitebox/blockout.tscn"):
        scene_text = FileAccess.get_file_as_string("res://demo/whitebox/blockout.tscn")
    return op.run(op.parse_scene(scene_text), _json("res://demo/whitebox/grid.json"))
