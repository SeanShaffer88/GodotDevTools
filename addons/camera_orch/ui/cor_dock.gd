## Camera Shake, Transition and Framing Orchestrator - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/camera_orch/core/cor_motion.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Camera Shake, Transition and Framing Orchestrator"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Camera Shake, Transition and Framing Orchestrator"
    title.tooltip_text = "Seeded deterministic shake, ease-curve transitions and deadzone framing maths with config validation."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Camera Shake, Transition and Framing Orchestrator on this project and list the results below."
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


const HELP_TEXT := "Camera motion maths with a determinism guarantee: shakes come from a hand-rolled seeded value noise, so the same seed replays the same shake on any platform; framing keeps a target inside a deadzone moving the camera as little as possible; transitions sample real ease curves. Run validates a shake and transition config and pre-computes preview samples; the runtime node applies the same functions to a live Camera2D."


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
    return op.run(_json("res://demo/camera/shake_config.json"))
