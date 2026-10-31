## Multi-Platform Input Matrix and Rebinding Suite - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/input_matrix/core/imx_matrix.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Multi-Platform Input Matrix and Rebinding Suite"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Multi-Platform Input Matrix and Rebinding Suite"
    title.tooltip_text = "Matrix of actions against devices, binding collisions, gamepad coverage gaps and generated remap-menu data."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Multi-Platform Input Matrix and Rebinding Suite on this project and list the results below."
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


const HELP_TEXT := "Builds the matrix of every input action against keyboard, mouse, gamepad and touch from the live InputMap or a JSON export. It reports one physical control bound to several actions, actions no gamepad can reach while the project supports gamepads, and emits remap-menu data - sorted, grouped, display-named - so a rebinding screen can be generated instead of hand-built. The runtime node handles live listening and saving new bindings."


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
    var actions: Dictionary = {}
    for action in InputMap.get_actions():
        if str(action).begins_with("ui_") or str(action).begins_with("spatial_editor"):
            continue
        var events: Array = []
        for ev in InputMap.action_get_events(str(action)):
            events.append(op.classify_event(ev))
        actions[str(action)] = events
    return op.run(actions)
