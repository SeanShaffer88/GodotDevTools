## Signal Flow and Event Bus Spy - session analysis operation.
## Analyzes a recorded signal session (the runtime node writes it, or a
## test fabricates it): every event is {fire_id, t_usec, signal,
## emitter, kind: emit|handle, listener, depth}. From that log this
## operation computes what the live viewer shows - emitter-to-listener
## latency per signal, emissions nobody listened to (dropped), the
## deepest cascade a handler chain reached, signals that re-fire inside
## their own handlers (recursion), and runaway chains (one signal firing
## absurdly often inside a short window). Verifying a session also
## checks the log itself: parses, timestamps in order, no handle without
## an emit. Pure data analysis, deterministic, headless-safe; the
## watching itself is runtime/sgs_bus.gd's job.
extends RefCounted

## One signal firing more than this many times inside the window below
## is a runaway: something is re-triggering itself.
var runaway_threshold: int = 25
var runaway_window_usec: int = 1000000
## Cascade depth beyond this is worth a look even without recursion.
var deep_cascade: int = 6


func load_session(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"errors": [{"severity": "error", "kind": "missing_file", "path": path,
            "message": "Signal session not found: %s" % path,
            "fix": "Record one with runtime/sgs_bus.gd (save_session), or check the path."}],
            "session": {}}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("events"):
        return {"errors": [{"severity": "error", "kind": "bad_json", "path": path,
            "message": "%s is not a signal session (no events list)." % path,
            "fix": "Re-record the session; the file is damaged or is not a spy log."}],
            "session": {}}
    return {"errors": [], "session": parsed}


## The one operation: analyze a session dict.
func analyze(session: Dictionary) -> Dictionary:
    var issues: Array = []
    var events: Array = session.get("events", [])
    var per_signal: Dictionary = {}
    var fires: Dictionary = {}
    var last_t := -1
    var order_broken := false
    var max_depth := 0
    for e in events:
        var ev: Dictionary = e
        var t := int(ev.get("t_usec", 0))
        if t < last_t:
            order_broken = true
        last_t = maxi(last_t, t)
        var sig := str(ev.get("signal", ""))
        var fire_id := str(ev.get("fire_id", ""))
        var depth := int(ev.get("depth", 0))
        max_depth = maxi(max_depth, depth)
        if not per_signal.has(sig):
            per_signal[sig] = {"fires": 0, "handles": 0, "latency_sum": 0,
                "latency_max": 0, "dropped": 0, "fire_times": []}
        var stats: Dictionary = per_signal[sig]
        if str(ev.get("kind", "")) == "emit":
            stats["fires"] = int(stats["fires"]) + 1
            (stats["fire_times"] as Array).append(t)
            fires[fire_id] = {"signal": sig, "t": t, "depth": depth, "handles": 0,
                "in_chain": _chain_signals(fires, str(ev.get("parent_fire", "")))}
            if depth > 0 and sig in (fires[fire_id]["in_chain"] as Array):
                issues.append({"severity": "error", "kind": "recursive_signal", "path": sig,
                    "message": "Signal '%s' re-fires inside its own handler chain (depth %d, fire %s)." % [sig, depth, fire_id],
                    "fix": "Break the loop: guard the emit with a flag, defer it (call_deferred), or move the reaction to a method that does not re-emit."})
        elif str(ev.get("kind", "")) == "handle":
            if not fires.has(fire_id):
                issues.append({"severity": "error", "kind": "orphan_handle", "path": sig,
                    "message": "A '%s' handler ran for fire %s, which was never emitted in this log." % [sig, fire_id],
                    "fix": "The log is incomplete or out of order - re-record with the bus watching from scene start."})
            else:
                stats["handles"] = int(stats["handles"]) + 1
                (fires[fire_id] as Dictionary)["handles"] = int((fires[fire_id] as Dictionary)["handles"]) + 1
                var latency := t - int((fires[fire_id] as Dictionary)["t"])
                stats["latency_sum"] = int(stats["latency_sum"]) + latency
                stats["latency_max"] = maxi(int(stats["latency_max"]), latency)
    for fire_id in fires:
        var f: Dictionary = fires[fire_id]
        if int(f["handles"]) == 0:
            var sig := str(f["signal"])
            (per_signal[sig] as Dictionary)["dropped"] = int((per_signal[sig] as Dictionary)["dropped"]) + 1
    if order_broken:
        issues.append({"severity": "error", "kind": "out_of_order", "path": "",
            "message": "Session timestamps go backwards somewhere - the log was edited or spliced.",
            "fix": "Re-record the session in one run; latency numbers from a spliced log mean nothing."})
    if max_depth > deep_cascade:
        issues.append({"severity": "warning", "kind": "deep_cascade", "path": "",
            "message": "A handler cascade reached depth %d (budget %d): one signal set off a chain that long." % [max_depth, deep_cascade],
            "fix": "Flatten the chain: react with deferred calls or an explicit event queue instead of nested emits."})
    for sig in per_signal:
        var times: Array = (per_signal[sig] as Dictionary)["fire_times"]
        var window_count := _max_in_window(times)
        if window_count > runaway_threshold:
            issues.append({"severity": "error", "kind": "runaway", "path": str(sig),
                "message": "Signal '%s' fired %d times inside one second (threshold %d) - a runaway emitter." % [sig, window_count, runaway_threshold],
                "fix": "Find the emit inside a handler or a _process loop; gate it with state so one event fires one signal."})
    var stats_out: Dictionary = {}
    for sig in per_signal:
        var st: Dictionary = per_signal[sig]
        var fired := int(st["fires"])
        stats_out[sig] = {"fires": fired, "handles": int(st["handles"]),
            "dropped": int(st["dropped"]),
            "avg_latency_usec": (int(st["latency_sum"]) / int(st["handles"])) if int(st["handles"]) > 0 else 0,
            "max_latency_usec": int(st["latency_max"])}
    var dropped_total := 0
    for sig in stats_out:
        dropped_total += int((stats_out[sig] as Dictionary)["dropped"])
    return {"summary": {"events": events.size(), "signals": per_signal.size(),
            "fires": fires.size(), "dropped": dropped_total, "max_depth": max_depth,
            "issues": issues.size()},
        "stats": stats_out, "issues": issues}


func _chain_signals(fires: Dictionary, parent_fire: String) -> Array:
    var chain: Array = []
    var current := parent_fire
    var guard := 0
    while current != "" and fires.has(current) and guard < 64:
        guard += 1
        chain.append(str((fires[current] as Dictionary)["signal"]))
        current = str((fires[current] as Dictionary).get("parent_fire", ""))
    return chain


func _max_in_window(times: Array) -> int:
    if times.is_empty():
        return 0
    var sorted_times := times.duplicate()
    sorted_times.sort()
    var best := 1
    var start := 0
    for end in range(1, sorted_times.size()):
        while int(sorted_times[end]) - int(sorted_times[start]) > runaway_window_usec:
            start += 1
        best = maxi(best, end - start + 1)
    return best


func run(session: Dictionary) -> Dictionary:
    return analyze(session)


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "stats": result.get("stats", {})}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Signal Spy Report", "",
        "%d events, %d signals, %d fires, %d dropped, deepest cascade %d. %d problems." % [
            s["events"], s["signals"], s["fires"], s["dropped"], s["max_depth"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
