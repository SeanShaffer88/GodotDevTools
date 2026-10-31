## Input Sequence Fuzzer - runtime replay node.
## Add to a test scene, assign `sequence` (one entry of the report's
## "sequences" array) and call play(). Each physics frame it releases and
## presses InputEventActions due on that frame, using the fuzzer core so
## replay timing matches the generated data exactly.
extends Node

const Core := preload("res://addons/input_fuzzer/core/isf_fuzzer.gd")

signal finished

@export var sequence: Dictionary = {}
var _core = Core.new()
var _frame: int = -1
var _last: int = 0


func play(seq: Dictionary = {}) -> void:
    if not seq.is_empty():
        sequence = seq
    _frame = 0
    _last = 0
    for st in sequence.get("steps", []):
        _last = max(_last, int(st["frame"]) + int(st["hold"]))


func _physics_process(_delta: float) -> void:
    if _frame < 0:
        return
    for ev in _core.events_for_frame(sequence, _frame):
        var e := InputEventAction.new()
        e.action = ev[0]
        e.pressed = ev[1]
        Input.parse_input_event(e)
    _frame += 1
    if _frame > _last:
        _frame = -1
        finished.emit()
