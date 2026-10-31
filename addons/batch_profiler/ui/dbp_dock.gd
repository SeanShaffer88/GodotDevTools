## Draw Call and Batching Profiler - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/batch_profiler/core/dbp_profiler.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Draw Call and Batching Profiler"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Draw Call and Batching Profiler"
    title.tooltip_text = "Find 2D draw-call breakers: material switches, z-index interleaving and light passes in your scenes."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Draw Call and Batching Profiler on this project and list the results below."
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


const HELP_TEXT := "Scans every .tscn in the project as text and reports CanvasItem siblings that alternate materials or z_index values, because each alternation can break a batch into an extra draw call, plus PointLight2D nodes, since every 2D light adds a render pass over the items it touches. The counts are draw-call-break suspects from scene structure, not GPU truth; confirm in the running game with the profiler monitors. The dock and the CLI call the same core, so headless CI sees exactly what the editor sees."


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
    return op.run()
