## Multi-Platform Input Matrix and Rebinding Suite - in-game rebinder.
## The live half of the suite: start_rebind("jump") and the next
## qualifying input event replaces that action's binding; bindings save
## to and load from a user:// JSON file using the same {device, id}
## vocabulary the matrix core reports in, so a saved rebinding file can
## be fed straight to the matrix analyzer to check the new layout for
## collisions before it ships. Autoload it or drop it in a menu scene;
## it never touches project.godot - user overrides live in user://.
extends Node

signal rebind_done(action: String, event: InputEvent)
signal rebind_cancelled(action: String)

const Matrix := preload("res://addons/input_matrix/core/imx_matrix.gd")

## Actions offered to the player for rebinding; empty means every
## non-ui action in the InputMap.
@export var rebindable_actions: Array[String] = []
@export var bindings_path: String = "user://rebinds.json"

var matrix = Matrix.new()
var listening: String = ""


## Begin listening: the next key, mouse button or pad control rebinds
## `action`. Call again with "" or cancel_rebind() to stop.
func start_rebind(action: String) -> void:
    listening = action


func cancel_rebind() -> void:
    if listening != "":
        var action := listening
        listening = ""
        rebind_cancelled.emit(action)


func _input(event: InputEvent) -> void:
    if listening == "":
        return
    if not _qualifies(event):
        return
    InputMap.action_erase_events(listening)
    InputMap.action_add_event(listening, event)
    var action := listening
    listening = ""
    get_viewport().set_input_as_handled()
    rebind_done.emit(action, event)


func _qualifies(event: InputEvent) -> bool:
    if event is InputEventKey:
        return (event as InputEventKey).pressed and not (event as InputEventKey).echo
    if event is InputEventMouseButton:
        return (event as InputEventMouseButton).pressed
    if event is InputEventJoypadButton:
        return (event as InputEventJoypadButton).pressed
    return false


func _actions() -> Array:
    if not rebindable_actions.is_empty():
        return rebindable_actions.duplicate()
    var out: Array = []
    for action in InputMap.get_actions():
        if not str(action).begins_with("ui_") and not str(action).begins_with("spatial_editor"):
            out.append(str(action))
    return out


## Current bindings in the matrix's {action: [{device, id}]} vocabulary.
func export_bindings() -> Dictionary:
    var out: Dictionary = {}
    for action in _actions():
        var events: Array = []
        for ev in InputMap.action_get_events(str(action)):
            events.append(matrix.classify_event(ev))
        out[str(action)] = events
    return out


func save_bindings(path: String = "") -> bool:
    var target := path if path != "" else bindings_path
    var f := FileAccess.open(target, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(export_bindings(), "\t"))
    f.close()
    return true


## Rebuild InputEvents from a saved bindings file and apply them.
func load_bindings(path: String = "") -> int:
    var source := path if path != "" else bindings_path
    if not FileAccess.file_exists(source):
        return 0
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(source))
    if typeof(parsed) != TYPE_DICTIONARY:
        return 0
    var applied := 0
    for action in parsed:
        if not InputMap.has_action(str(action)):
            continue
        InputMap.action_erase_events(str(action))
        for e in parsed[action]:
            var ev := _event_from(e)
            if ev != null:
                InputMap.action_add_event(str(action), ev)
                applied += 1
    return applied


func _event_from(record: Dictionary) -> InputEvent:
    var device := str(record.get("device", ""))
    var id := str(record.get("id", ""))
    match device:
        "keyboard":
            var key := InputEventKey.new()
            key.physical_keycode = OS.find_keycode_from_string(id)
            return key if key.physical_keycode != 0 else null
        "mouse":
            if id.begins_with("button_"):
                var mb := InputEventMouseButton.new()
                mb.button_index = int(id.trim_prefix("button_"))
                return mb
        "joypad":
            if id.begins_with("button_"):
                var jb := InputEventJoypadButton.new()
                jb.button_index = int(id.trim_prefix("button_"))
                return jb
            if id.begins_with("axis_"):
                var parts := id.trim_prefix("axis_").split("_")
                if parts.size() == 2:
                    var jm := InputEventJoypadMotion.new()
                    jm.axis = int(parts[0])
                    jm.axis_value = 1.0 if parts[1] == "+" else -1.0
                    return jm
    return null
