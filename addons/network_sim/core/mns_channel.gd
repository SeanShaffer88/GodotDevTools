## Multiplayer Network Simulator - simulated network channel.
## A deterministic, seeded model of a bad network: every message sent
## through the channel is delayed by the configured latency plus random
## jitter, dropped with the configured loss probability, duplicated if
## duplication is on, and held entirely during scheduled disconnect
## windows. Two channels (one per direction) plus a state-hash log give
## the synchronisation inspector: run the same inputs through two
## simulated peers and compare the hash each peer reports per tick -
## the first tick where hashes differ is where the game desynced.
## Pure logic on an integer tick clock, so tests and CI reproduce the
## exact same bad network every run.
extends RefCounted

var latency_ticks: int = 6        ## base one-way delay (6 ticks = 100 ms at 60 tps)
var jitter_ticks: int = 3         ## extra random delay, 0..jitter
var loss_fraction: float = 0.05   ## 0.0 - 1.0
var duplicate_fraction: float = 0.0
var disconnect_windows: Array[Vector2i] = [] ## [from_tick, to_tick) - nothing is delivered
var seed_value: int = 12345

var _rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = [] ## {deliver_tick, payload, seq}
var _seq: int = 0
var _now: int = 0

var stats: Dictionary = {"sent": 0, "delivered": 0, "dropped_loss": 0,
    "dropped_disconnect": 0, "duplicated": 0, "max_delay": 0}


func _init() -> void:
    _rng.seed = seed_value


func reset(new_seed: int = -1) -> void:
    if new_seed >= 0:
        seed_value = new_seed
    _rng.seed = seed_value
    _queue.clear()
    _seq = 0
    _now = 0
    stats = {"sent": 0, "delivered": 0, "dropped_loss": 0,
        "dropped_disconnect": 0, "duplicated": 0, "max_delay": 0}


func now() -> int:
    return _now


func _in_disconnect(tick: int) -> bool:
    for win in disconnect_windows:
        if tick >= win.x and tick < win.y:
            return true
    return false


## Offer a message to the network at the current tick.
func send(payload: Dictionary) -> void:
    stats["sent"] = int(stats["sent"]) + 1
    if _in_disconnect(_now):
        stats["dropped_disconnect"] = int(stats["dropped_disconnect"]) + 1
        return
    if _rng.randf() < loss_fraction:
        stats["dropped_loss"] = int(stats["dropped_loss"]) + 1
        return
    var delay := latency_ticks + _rng.randi_range(0, maxi(jitter_ticks, 0))
    _enqueue(payload, delay)
    if duplicate_fraction > 0.0 and _rng.randf() < duplicate_fraction:
        stats["duplicated"] = int(stats["duplicated"]) + 1
        _enqueue(payload, delay + _rng.randi_range(0, 2))


func _enqueue(payload: Dictionary, delay: int) -> void:
    _seq += 1
    _queue.append({"deliver_tick": _now + delay, "payload": payload.duplicate(true),
        "seq": _seq, "sent_tick": _now})


## Advance one tick; returns the messages delivered on this tick,
## in send order.
func advance() -> Array:
    _now += 1
    var out: Array = []
    var keep: Array[Dictionary] = []
    for item in _queue:
        if int(item["deliver_tick"]) <= _now:
            if _in_disconnect(_now):
                stats["dropped_disconnect"] = int(stats["dropped_disconnect"]) + 1
                continue
            stats["delivered"] = int(stats["delivered"]) + 1
            stats["max_delay"] = maxi(int(stats["max_delay"]), _now - int(item["sent_tick"]))
            out.append(item["payload"])
        else:
            keep.append(item)
    _queue = keep
    out.sort_custom(func(a, b): return false) # order preserved from queue; no-op for clarity
    return out


## Compare two peers' per-tick state hashes: returns the first tick
## where they differ, or -1 when the runs stayed in sync.
static func first_desync_tick(hashes_a: Array, hashes_b: Array) -> int:
    var n := mini(hashes_a.size(), hashes_b.size())
    for i in n:
        if str(hashes_a[i]) != str(hashes_b[i]):
            return i
    if hashes_a.size() != hashes_b.size():
        return n
    return -1


## A built-in demonstration / self-check scenario: a server sends 120
## authoritative state updates through the configured channel; the
## client applies what arrives and hashes its state each tick. Packet
## loss shows up as missing updates (the desync the inspector reports).
func run_sync_scenario(ticks: int = 180) -> Dictionary:
    reset()
    var channel = self
    var server_state := {"score": 0, "tick": 0}
    var client_state := {"score": 0, "tick": 0}
    var sent_updates := 0
    for t in ticks:
        server_state["tick"] = t
        server_state["score"] = t * 10
        channel.send({"kind": "state", "tick": t, "score": t * 10})
        sent_updates += 1
        var arrived: Array = channel.advance()
        for msg in arrived:
            if int(msg.get("tick", -1)) > int(client_state["tick"]):
                client_state["tick"] = int(msg["tick"])
                client_state["score"] = int(msg["score"])
    # Drain: the server stops changing state and the channel gets time
    # to deliver what is still in flight. After the drain, a healthy
    # channel leaves the client holding exactly the server's final
    # state; anything lost on the way shows up as a final mismatch.
    for d in 40:
        var late: Array = channel.advance()
        for msg in late:
            if int(msg.get("tick", -1)) > int(client_state["tick"]):
                client_state["tick"] = int(msg["tick"])
                client_state["score"] = int(msg["score"])
    var server_final := JSON.stringify(server_state).md5_text()
    var client_final := JSON.stringify(client_state).md5_text()
    var desync := -1 if server_final == client_final else int(client_state["tick"])
    var issues: Array = []
    if int(stats["dropped_loss"]) > 0 or int(stats["dropped_disconnect"]) > 0:
        issues.append({"severity": "warning", "kind": "packet_loss", "path": "",
            "message": "%d of %d updates never arrived (%d lost, %d during disconnects). The client state fell behind the server - in a real game this is where rubber-banding and desync appear." % [
                int(stats["dropped_loss"]) + int(stats["dropped_disconnect"]), sent_updates,
                int(stats["dropped_loss"]), int(stats["dropped_disconnect"])],
            "fix": "Send state as snapshots with sequence numbers and let the client request or interpolate across gaps, instead of assuming every update arrives."})
    return {"summary": {"ticks": ticks, "sent": sent_updates, "delivered": int(stats["delivered"]),
            "dropped": int(stats["dropped_loss"]) + int(stats["dropped_disconnect"]),
            "first_desync_tick": desync, "max_delay_ticks": int(stats["max_delay"]), "issues": issues.size()},
        "issues": issues, "server_final_hash": server_final, "client_final_hash": client_final,
        "server_state": server_state, "client_state": client_state}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Network Simulation Report", "",
        "%d ticks: %d updates sent, %d delivered, %d dropped, worst delay %d ticks, first desync at tick %d (-1 = stayed in sync)." % [
            s["ticks"], s["sent"], s["delivered"], s["dropped"], s["max_delay_ticks"], s["first_desync_tick"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
