## Signal Flow and Event Bus Spy - in-game recording bus.
## An event bus that spies on itself: emit_tracked() records every
## emission with a fire id, timestamp and cascade depth, subscribers to
## `fired` react and then call note_handled() so the log carries both
## sides of every conversation. save_session() writes the exact JSON
## shape the analyzer core (and the session fixture) consume, so a bug
## reproduced in a play session becomes a report in one CLI call. Nested
## emit_tracked() calls inside a handler are recorded with their parent
## fire id and depth - that is how the analyzer later sees cascades and
## recursion. Autoload it as SpyBus, or parent it to anything.
extends Node

## Carries {"signal": name, "fire_id": id, "payload": payload} for each
## tracked emission. Subscribers react, then call note_handled().
signal fired(entry: Dictionary)

## True while emissions are recorded; set false to silence the spy
## without disconnecting subscribers.
@export var recording: bool = true

var events: Array = []
var started_usec: int = 0

var _fire_counter := 0
var _depth := 0
var _chain: Array = []


func _ready() -> void:
    started_usec = Time.get_ticks_usec()


## Record and broadcast one emission. Handlers connected to `fired` run
## synchronously inside this call, so anything they emit lands in the
## log as a deeper child of this fire.
func emit_tracked(signal_name: String, emitter: String, payload: String = "") -> String:
    _fire_counter += 1
    var id := "f%d" % _fire_counter
    if recording:
        events.append({"fire_id": id, "t_usec": Time.get_ticks_usec() - started_usec,
            "signal": signal_name, "emitter": emitter, "kind": "emit", "listener": "",
            "depth": _depth, "parent_fire": str(_chain.back()) if not _chain.is_empty() else ""})
    _chain.append(id)
    _depth += 1
    fired.emit({"signal": signal_name, "fire_id": id, "payload": payload})
    _depth -= 1
    _chain.pop_back()
    return id


## Record that `listener` handled the emission currently in flight.
## Call it at the end of your `fired` subscriber.
func note_handled(signal_name: String, listener: String) -> void:
    if not recording or _chain.is_empty():
        return
    events.append({"fire_id": str(_chain.back()), "t_usec": Time.get_ticks_usec() - started_usec,
        "signal": signal_name, "emitter": "", "kind": "handle", "listener": listener,
        "depth": _depth, "parent_fire": ""})


## How deep the current cascade is (0 = not inside any emission).
func cascade_depth() -> int:
    return _depth


func session() -> Dictionary:
    return {"session": {"started_usec": started_usec}, "events": events}


func save_session(path: String = "user://signal_session.json") -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(session(), "\t"))
    f.close()
    return true


## Drop the log without touching subscribers.
func clear_session() -> void:
    events = []
    _fire_counter = 0
    started_usec = Time.get_ticks_usec()
