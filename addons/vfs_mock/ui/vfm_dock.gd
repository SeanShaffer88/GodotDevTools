## Cross-Platform Virtual Filesystem Mock - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/vfs_mock/core/vfm_fs.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Cross-Platform Virtual Filesystem Mock"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Cross-Platform Virtual Filesystem Mock"
    title.tooltip_text = "Resolve file ops against linux, windows, android and ios rules; audit scripts for platform-specific path literals."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Cross-Platform Virtual Filesystem Mock on this project and list the results below."
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


const HELP_TEXT := "Every platform's filesystem has different rules and the difference bites after export. This mock models four profiles - linux, windows, android, ios - as data and resolves file operations against them: case mismatches that 404 on Linux while Windows hides the bug, sandbox escapes through dot-dot segments, writes into read-only roots, reserved device names, forbidden characters, over-long paths. It also audits scripts for backslash and drive-letter literals."


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
