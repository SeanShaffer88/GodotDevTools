## Browsable directed dependency map; each row expands to its outgoing edges.
@tool
extends VBoxContainer

const Core := preload("res://addons/scene_dependency/core/sdm_graph.gd")
var _map: Tree
var _status: RichTextLabel

func _init() -> void:
    name = "Scene Dependency Map"
    custom_minimum_size = Vector2(320, 300)
    var button := Button.new()
    button.text = "Scan dependencies"
    button.tooltip_text = "Build a static map from literal resource paths."
    button.pressed.connect(_on_run)
    add_child(button)
    _status = RichTextLabel.new()
    _status.custom_minimum_size = Vector2(300, 100)
    _status.tooltip_text = "Findings are static suspects; dynamic loads require manual review."
    add_child(_status)
    _map = Tree.new()
    _map.hide_root = true
    _map.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _map.tooltip_text = "Expand a file to see the files it directly references."
    add_child(_map)
    _status.text = "Scan to see files, dependency edges and findings. Unreachable assets are candidates, not safe-to-delete proof."

func _on_run() -> void:
    var result: Dictionary = Core.new().run()
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s\n  %s" % [issue["kind"], issue["message"], issue["fix"]])
    _status.text = "\n".join(lines)
    _map.clear()
    var root := _map.create_item()
    var rows := {}
    for path in result["nodes"]:
        var item := _map.create_item(root)
        var label := str(path) + (" (entry point)" if path in result["roots"] else "")
        for singleton in result.get("autoloads", {}):
            if result["autoloads"][singleton] == path:
                label += " (autoload: " + str(singleton) + ")"
        item.set_text(0, label)
        rows[path] = item
    for edge in result["edges"]:
        var item := _map.create_item(rows[edge["from"]])
        item.set_text(0, "→ " + str(edge["to"]))
