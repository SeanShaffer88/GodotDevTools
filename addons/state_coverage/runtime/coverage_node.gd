## Add this node to a game and call record_transition when its state changes.
extends Node

const Recorder := preload("res://addons/state_coverage/core/coverage_recorder.gd")
@export_range(1, 100000, 1) var max_transitions: int = 10000
@export var recording: bool = true
var recorder = Recorder.new()

func record_transition(from_state: String, to_state: String) -> bool:
    if not recording:
        return false
    recorder.max_transitions = max_transitions
    return recorder.record_transition(from_state, to_state)

func start_sequence() -> void:
    recorder.start_sequence()

func clear() -> void:
    recorder.clear()

func snapshot() -> Dictionary:
    return recorder.snapshot()

## Writes only on explicit request. Returns the Godot error code.
func save_trace(path: String) -> Error:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(snapshot(), "  "))
    file.flush()
    return file.get_error()
