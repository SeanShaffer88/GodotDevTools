## Game-State Time Machine - in-game recorder node.
## Add this node to your game, list the state providers (Callables that
## return a Dictionary of the state worth rewinding), and it records
## every physics frame. Call rewind_to(frame) to restore a snapshot:
## each registered restorer Callable receives the snapshot Dictionary.
## Input events from the actions in tracked_actions are recorded with
## the frame they arrived on.
extends Node

const Recorder := preload("res://addons/time_machine/core/gstm_recorder.gd")

var recorder = Recorder.new()
var state_providers: Array[Callable] = []
var state_restorers: Array[Callable] = []
var tracked_actions: Array[String] = ["ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down"]
var recording: bool = true

var _pending_inputs: Array = []


func _unhandled_input(event: InputEvent) -> void:
    if not recording:
        return
    for action in tracked_actions:
        if event.is_action(action):
            _pending_inputs.append({"action": action, "pressed": event.is_action_pressed(action)})


func _physics_process(_delta: float) -> void:
    if not recording:
        return
    var state: Dictionary = {}
    for provider in state_providers:
        state.merge(provider.call())
    recorder.record(_pending_inputs, state)
    _pending_inputs = []


## Rewind: hand the snapshot at `frame` to every restorer and return it
## (empty Dictionary if that frame aged out of the buffer).
func rewind_to(frame: int) -> Dictionary:
    var snap := recorder.snapshot_at(frame)
    if snap.is_empty():
        return snap
    for restorer in state_restorers:
        restorer.call(snap.duplicate(true))
    return snap
