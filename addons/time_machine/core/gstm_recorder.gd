## Game-State Time Machine - recording operation.
## Records, per simulated frame: the inputs that arrived and a snapshot
## of the tracked state (a Dictionary the game supplies each frame).
## Supports rewind (restore the snapshot at any recorded frame), replay
## (the exact input list that produced a frame range), state diffing
## between two frames, and saving / loading a whole session as JSON so a
## bug report carries the exact sequence that caused the bug.
## Pure logic: the game decides what goes into a snapshot; this class
## stores, indexes and restores it. Snapshots are deep-copied on record
## and on restore, so later mutation never rewrites history.
extends RefCounted

var max_frames: int = 36000 ## 10 minutes at 60 fps; oldest frames drop off.

var _frames: Array[Dictionary] = [] ## {frame, inputs: Array, state: Dictionary}
var _next_frame: int = 0


func clear() -> void:
    _frames.clear()
    _next_frame = 0


func frame_count() -> int:
    return _frames.size()


func latest_frame() -> int:
    return -1 if _frames.is_empty() else int(_frames[_frames.size() - 1]["frame"])


## Record one frame. inputs: Array of Dictionaries like
## {"action": "jump", "pressed": true} (any JSON-shaped data works).
func record(inputs: Array, state: Dictionary) -> int:
    var f := _next_frame
    _next_frame += 1
    _frames.append({"frame": f, "inputs": inputs.duplicate(true), "state": state.duplicate(true)})
    while _frames.size() > max_frames:
        _frames.pop_front()
    return f


func _find(frame: int) -> Dictionary:
    for rec in _frames:
        if int(rec["frame"]) == frame:
            return rec
    return {}


## The snapshot at a frame (deep copy), or {} if it was not recorded /
## has aged out of the ring buffer.
func snapshot_at(frame: int) -> Dictionary:
    var rec := _find(frame)
    return {} if rec.is_empty() else (rec["state"] as Dictionary).duplicate(true)


func inputs_at(frame: int) -> Array:
    var rec := _find(frame)
    return [] if rec.is_empty() else (rec["inputs"] as Array).duplicate(true)


## Every input recorded from frame a to frame b inclusive, in order,
## each tagged with its frame - the exact replay script for a bug.
func replay_script(from_frame: int, to_frame: int) -> Array:
    var out: Array = []
    for rec in _frames:
        var f := int(rec["frame"])
        if f >= from_frame and f <= to_frame:
            for inp in rec["inputs"]:
                var d: Dictionary = (inp as Dictionary).duplicate(true)
                d["frame"] = f
                out.append(d)
    return out


## What changed between two snapshots: {key: {"from":..., "to":...}}
## for keys whose values differ, plus added / removed keys.
func diff_states(frame_a: int, frame_b: int) -> Dictionary:
    var a := snapshot_at(frame_a)
    var b := snapshot_at(frame_b)
    var out: Dictionary = {}
    for k in a:
        if not b.has(k):
            out[k] = {"from": a[k], "to": null, "change": "removed"}
        elif str(a[k]) != str(b[k]):
            out[k] = {"from": a[k], "to": b[k], "change": "changed"}
    for k in b:
        if not a.has(k):
            out[k] = {"from": null, "to": b[k], "change": "added"}
    return out


## A short fingerprint of a frame's state, for spotting the exact frame
## where a replay diverges from the original run.
func state_hash(frame: int) -> String:
    var rec := _find(frame)
    if rec.is_empty():
        return ""
    return JSON.stringify(rec["state"]).md5_text()


func save_session(path: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify({"version": 1, "frames": _frames}, "\t"))
    f.close()
    return true


func load_session(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("frames"):
        return false
    clear()
    for rec in parsed["frames"]:
        _frames.append({"frame": int(rec["frame"]), "inputs": rec["inputs"], "state": rec["state"]})
        _next_frame = maxi(_next_frame, int(rec["frame"]) + 1)
    return true


## Verify a saved session file: parses, counts frames/inputs, and checks
## frame numbers are strictly increasing (a corrupt or hand-edited
## session fails here instead of mid-replay).
func verify_session(path: String) -> Dictionary:
    var issues: Array = []
    if not FileAccess.file_exists(path):
        return {"summary": {"frames": 0, "inputs": 0}, "issues": [{"severity": "error", "kind": "missing_session",
            "path": path, "message": "Session file not found: %s" % path,
            "fix": "Record a session first, or pass the right --session path."}], "frames": []}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("frames"):
        issues.append({"severity": "error", "kind": "bad_session", "path": path,
            "message": "Session file is not valid Time Machine JSON.",
            "fix": "Re-record the session; this file is damaged or was edited by hand."})
        return {"summary": {"frames": 0, "inputs": 0}, "issues": issues, "frames": []}
    var last := -1
    var inputs := 0
    for rec in parsed["frames"]:
        if int(rec["frame"]) <= last:
            issues.append({"severity": "error", "kind": "frame_order", "path": path,
                "message": "Frame %d follows frame %d - frames must increase." % [int(rec["frame"]), last],
                "fix": "Re-record the session; its frame order is broken."})
        last = int(rec["frame"])
        inputs += (rec["inputs"] as Array).size()
    return {"summary": {"frames": (parsed["frames"] as Array).size(), "inputs": inputs},
        "issues": issues, "frames": parsed["frames"]}
