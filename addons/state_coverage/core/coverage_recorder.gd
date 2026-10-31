## Bounded, opt-in transition trace recorder. It does not instrument state machines automatically.
extends RefCounted

var max_transitions: int = 10000
var _transitions: Array = []
var _dropped: int = 0
var _next_reset: bool = false

## A new session clears all old events and truncation information.
func clear() -> void:
    _transitions.clear()
    _dropped = 0
    _next_reset = false

## Mark the next valid transition as the start of an independent sequence.
func start_sequence() -> void:
    _next_reset = true

## Return false for invalid names or an invalid buffer size; never record partial events.
func record_transition(from_state: String, to_state: String) -> bool:
    if from_state.is_empty() or to_state.is_empty() or max_transitions < 1:
        return false
    var edge := {"from": from_state, "to": to_state}
    if _next_reset:
        edge["reset"] = true
        _next_reset = false
    _transitions.append(edge)
    while _transitions.size() > max_transitions:
        _transitions.pop_front()
        _dropped += 1
    return true

## Return a detached snapshot; consumers may safely mutate it.
func snapshot() -> Dictionary:
    return {"transitions": _transitions.duplicate(true), "truncated": _dropped > 0, "dropped": _dropped}
