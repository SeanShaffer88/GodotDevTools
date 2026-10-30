## Multiplayer Network Simulator - editor dock.
@tool
extends VBoxContainer

const Channel := preload("res://addons/network_sim/core/mns_channel.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Multiplayer Network Simulator"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Multiplayer Network Simulator"
    title.tooltip_text = "Add configurable latency, packet loss and disconnects to local multiplayer testing, with tools to inspect synchronisation issues."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Multiplayer Network Simulator check on this project and list the results below."
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


const HELP_TEXT := "Run plays the built-in sync scenario: 180 authoritative updates through a channel with 150 ms latency and 10% loss; dropped updates show up as a final-state mismatch (the desync). In game, route packets through the Network Sim Proxy node (addons/network_sim/runtime/mns_proxy.gd) and set its latency/loss; compare two peers with Channel.first_desync_tick(a, b)."


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
    var results_list: Array = result.get("results", [])
    for r in results_list:
        lines.append("%s - %s" % [r.get("path", ""), "; ".join(r.get("reasons", []))])
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Channel.new()
    op.loss_fraction = 0.1
    op.latency_ticks = 9
    return op.run_sync_scenario(180)
