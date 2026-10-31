## Signal Flow and Event Bus Spy - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/signal_spy/core/sgs_analyzer.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Signal Flow and Event Bus Spy"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Signal Flow and Event Bus Spy"
    title.tooltip_text = "Analyze recorded signal sessions: latency, dropped emissions, cascades, recursion and runaway emitters."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Signal Flow and Event Bus Spy on this project and list the results below."
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


const HELP_TEXT := "Analyzes a recorded signal session: emitter-to-listener latency per signal, emissions nobody handled, the deepest handler cascade, signals that re-fire inside their own chains, and runaway emitters firing dozens of times a second. The runtime bus node records sessions from a live game and saves them as JSON; this analysis answers the question every signal bug starts with: who emitted, who heard it, how late, and did it loop."


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
    var loaded := op.load_session("res://demo/signals/session.json")
    var result: Dictionary = op.analyze(loaded["session"])
    result["issues"] = (loaded["errors"] as Array) + (result.get("issues", []) as Array)
    result["summary"]["issues"] = (result["issues"] as Array).size()
    return result
