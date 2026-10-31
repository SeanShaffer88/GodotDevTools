## Audio Bus and Dynamic Mixing Sandbox - mix simulation operation.
## Takes a bus layout, ducking rules, reverb zones, a voice budget and a
## timeline of mixing events as pure data, then simulates the mix on a
## fixed 10 ms clock: gain ramps per ducked bus, voice allocation with
## priority eviction, zone enter/exit pairing. Designers tune the numbers
## and re-run - no game loop, no audio driver, fully deterministic. The
## report flags designs that fight themselves: ducking loops, references
## to buses that do not exist, zones that are entered and never left,
## and how often the voice budget forced an eviction.
extends RefCounted

var step_ms: int = 10


## The one operation. Layout shape:
## {"buses": [{"name": "Master"}, {"name": "Music", "send": "Master"}],
##  "ducks": [{"trigger": "SFX", "target": "Music", "db": -6.0,
##             "attack_ms": 50, "release_ms": 300}],
##  "zones": [{"name": "cave", "bus": "SFX"}],
##  "voices": {"max": 8, "priority": {"SFX": 2, "Music": 1, "VO": 3}},
##  "events": [{"t_ms": 0, "type": "voice_start", "bus": "SFX"},
##             {"t_ms": 100, "type": "duck_on", "bus": "SFX"}, ...]}
func simulate(layout: Dictionary) -> Dictionary:
    var issues: Array = []
    var bus_names: Dictionary = {}
    for b in layout.get("buses", []):
        bus_names[str(b.get("name", ""))] = b
    for b in layout.get("buses", []):
        var send := str(b.get("send", ""))
        if send != "" and not bus_names.has(send):
            issues.append({"severity": "error", "kind": "missing_bus", "path": str(b.get("name", "")),
                "message": "Bus '%s' sends to '%s', which is not in the layout." % [b.get("name"), send],
                "fix": "Add the missing bus, or point the send at an existing one."})
    var ducks: Array = layout.get("ducks", [])
    for d in ducks:
        for key in ["trigger", "target"]:
            if not bus_names.has(str(d.get(key, ""))):
                issues.append({"severity": "error", "kind": "missing_bus", "path": str(d.get("trigger", "")),
                    "message": "Duck rule '%s' -> '%s' references a bus that is not in the layout." % [d.get("trigger"), d.get("target")],
                    "fix": "Fix the bus name in the duck rule or add the bus."})
    for cycle in _duck_cycles(ducks):
        issues.append({"severity": "error", "kind": "duck_loop", "path": str(cycle[0]),
            "message": "Ducking loops: %s. Each bus ducks another that ducks it back - the mix can collapse to silence." % " -> ".join(cycle),
            "fix": "Break the loop: one bus in the circle must not duck another member of it."})
    var horizon := 0
    for e in layout.get("events", []):
        horizon = maxi(horizon, int(e.get("t_ms", 0)))
    horizon += 1000
    var voice_cfg: Dictionary = layout.get("voices", {})
    var max_voices := int(voice_cfg.get("max", 8))
    var priority: Dictionary = voice_cfg.get("priority", {})
    var active: Array = []
    var duck_state: Dictionary = {}
    var zone_open: Dictionary = {}
    var timeline: Array = []
    var evictions := 0
    var peak_voices := 0
    var t := 0
    while t <= horizon:
        for e in layout.get("events", []):
            if int(e.get("t_ms", -1)) != t:
                continue
            var bus := str(e.get("bus", ""))
            match str(e.get("type", "")):
                "duck_on":
                    duck_state[bus] = {"on_at": t, "off_at": -1}
                "duck_off":
                    if duck_state.has(bus):
                        (duck_state[bus] as Dictionary)["off_at"] = t
                "voice_start":
                    active.append({"bus": bus, "started": t,
                        "priority": int(priority.get(bus, 0))})
                    if active.size() > max_voices:
                        active.sort_custom(func(a, b): return int(a["priority"]) > int(b["priority"]))
                        var dropped: Dictionary = active.pop_back()
                        evictions += 1
                        issues.append({"severity": "info", "kind": "voice_eviction", "path": bus,
                            "message": "At %d ms the voice budget (%d) forced dropping a '%s' voice (priority %d)." % [t, max_voices, dropped["bus"], dropped["priority"]],
                            "fix": "Raise the voice budget, lower this bus's priority, or thin overlapping events."})
                "voice_stop":
                    for i in range(active.size() - 1, -1, -1):
                        if str((active[i] as Dictionary)["bus"]) == bus:
                            active.remove_at(i)
                            break
                "zone_enter":
                    zone_open[bus] = t
                "zone_exit":
                    zone_open.erase(bus)
        peak_voices = maxi(peak_voices, active.size())
        var gains: Dictionary = {}
        for d in ducks:
            var trig := str(d.get("trigger", ""))
            var target := str(d.get("target", ""))
            if not duck_state.has(trig):
                continue
            var st: Dictionary = duck_state[trig]
            var db := float(d.get("db", -6.0))
            var attack := maxi(int(d.get("attack_ms", 50)), 1)
            var release := maxi(int(d.get("release_ms", 300)), 1)
            var amount := 0.0
            var off_at := int(st["off_at"])
            if off_at < 0:
                amount = db * clampf(float(t - int(st["on_at"])) / float(attack), 0.0, 1.0)
            else:
                var held := db * clampf(float(off_at - int(st["on_at"])) / float(attack), 0.0, 1.0)
                amount = held * (1.0 - clampf(float(t - off_at) / float(release), 0.0, 1.0))
            gains[target] = float(gains.get(target, 0.0)) + amount
        timeline.append({"t_ms": t, "gains": gains, "voices": active.size()})
        t += step_ms
    for zone in zone_open:
        issues.append({"severity": "warning", "kind": "zone_stuck", "path": str(zone),
            "message": "Reverb zone '%s' is entered at %d ms and never exited within the timeline." % [zone, int(zone_open[zone])],
            "fix": "Add the matching zone_exit event, or the zone's tail will hang over everything after it."})
    return {"summary": {"buses": bus_names.size(), "ducks": ducks.size(),
            "horizon_ms": horizon, "evictions": evictions, "peak_voices": peak_voices,
            "issues": issues.size()},
        "timeline": timeline, "issues": issues}


func run(layout: Dictionary) -> Dictionary:
    return simulate(layout)


func _duck_cycles(ducks: Array) -> Array:
    var edges: Dictionary = {}
    for d in ducks:
        var trig := str(d.get("trigger", ""))
        var target := str(d.get("target", ""))
        if trig == "" or target == "":
            continue
        if not edges.has(trig):
            edges[trig] = []
        (edges[trig] as Array).append(target)
    var cycles: Array = []
    var state: Dictionary = {}
    var stack: Array = []
    for node in edges:
        _dfs(str(node), edges, state, stack, cycles)
    return cycles


func _dfs(node: String, edges: Dictionary, state: Dictionary, stack: Array, cycles: Array) -> void:
    if int(state.get(node, 0)) == 2:
        return
    if int(state.get(node, 0)) == 1:
        var idx: int = stack.find(node)
        if idx >= 0:
            cycles.append(stack.slice(idx) + [node])
        return
    state[node] = 1
    stack.append(node)
    for nxt in edges.get(node, []):
        _dfs(str(nxt), edges, state, stack, cycles)
    stack.pop_back()
    state[node] = 2


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Audio Mix Simulation Report", "",
        "%d buses, %d duck rules, %d ms horizon, %d voice eviction(s), peak %d voices. %d problems." % [
            s["buses"], s["ducks"], s["horizon_ms"], s["evictions"], s["peak_voices"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
