## Behaviour Tree and State Machine Debugger - in-game agent node.
## Drives a real scene from the same JSON definitions and the same
## interpreter the debugger dock uses (core/btd_machine.gd): point
## definition_path at a behaviour file, and the agent ticks it on a
## fixed interval, keeping its own blackboard and emitting every trace
## entry as it happens. Connect trace_entry to a debug overlay and you
## are watching the live decision stream - the exact events the dock
## replays from a saved definition. Game code feeds the blackboard
## (agent.blackboard["player_visible"] = true) and reads the state.
extends Node

signal state_changed(from_state: String, to_state: String)
signal trace_entry(entry: Dictionary)

const Machine := preload("res://addons/bt_debugger/core/btd_machine.gd")

@export_file("*.json") var definition_path: String = ""
## Machine ticks per second; behaviour logic rarely needs 60.
@export var ticks_per_second: float = 4.0
@export var enabled: bool = true

var machine = Machine.new()
var definition: Dictionary = {}
var blackboard: Dictionary = {}
var current_state: String = ""
var trace: Array = []

var _accumulator := 0.0
var _load_errors: Array = []


func _ready() -> void:
    load_definition(definition_path)


func load_definition(path: String) -> void:
    var loaded := machine.load_definition(path)
    _load_errors = loaded["errors"]
    definition = loaded["definition"]
    blackboard = (definition.get("blackboard", {}) as Dictionary).duplicate()
    current_state = str(definition.get("initial", ""))
    trace = []


## Any load errors from the definition file (empty when it loaded).
func load_errors() -> Array:
    return _load_errors


func _process(delta: float) -> void:
    if not enabled or current_state == "":
        return
    _accumulator += delta
    var interval := 1.0 / maxf(ticks_per_second, 0.001)
    while _accumulator >= interval:
        _accumulator -= interval
        step()


## Run exactly one machine tick: enter state, run its tree, take the
## first transition whose guard passes.
func step() -> String:
    var before := trace.size()
    var next := machine.step(current_state, definition, blackboard, trace)
    for i in range(before, trace.size()):
        trace_entry.emit(trace[i])
    if next != "" and next != current_state:
        var previous := current_state
        current_state = next
        state_changed.emit(previous, next)
    return next
