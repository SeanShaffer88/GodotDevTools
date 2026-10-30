## Network Simulator tests.
extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0


func _check(label: String, ok: bool, evidence: String = "") -> void:
    if ok:
        _passes += 1
        print("PASS  ", label)
    else:
        _failures.append(label)
        print("FAIL  ", label, "  ", evidence)


func _finish(name: String) -> void:
    print("----")
    print(name, ": %d passed, %d failed" % [_passes, _failures.size()])
    quit(1 if not _failures.is_empty() else 0)


func _kinds(issues: Array) -> Array:
    var out: Array = []
    for i in issues:
        out.append(i["kind"])
    return out

const Channel := preload("res://addons/network_sim/core/mns_channel.gd")


func _init() -> void:
    var ch = Channel.new()
    ch.loss_fraction = 0.0
    ch.latency_ticks = 2
    ch.jitter_ticks = 0
    ch.reset()
    ch.send({"n": 1})
    ch.send({"n": 2})
    var got: Array = []
    for i in 5:
        got.append_array(ch.advance())
    _check("lossless channel delivers everything", got.size() == 2, str(got))
    _check("delivery order preserved", got.size() == 2 and int(got[0]["n"]) == 1 and int(got[1]["n"]) == 2)
    _check("stats count delivery", int(ch.stats["delivered"]) == 2 and int(ch.stats["sent"]) == 2)
    var dead = Channel.new()
    dead.loss_fraction = 1.0
    dead.reset()
    dead.send({"n": 1})
    dead.send({"n": 2})
    dead.send({"n": 3})
    var none: Array = []
    for i in 10:
        none.append_array(dead.advance())
    _check("100% loss delivers nothing and counts drops", none.is_empty() and int(dead.stats["dropped_loss"]) == 3, str(dead.stats))
    var dup = Channel.new()
    dup.loss_fraction = 0.0
    dup.duplicate_fraction = 1.0
    dup.latency_ticks = 1
    dup.jitter_ticks = 0
    dup.reset()
    dup.send({"n": 7})
    var twice: Array = []
    for i in 6:
        twice.append_array(dup.advance())
    _check("duplication delivers the packet twice", twice.size() == 2, str(twice))
    var disc = Channel.new()
    disc.loss_fraction = 0.0
    disc.latency_ticks = 1
    disc.jitter_ticks = 0
    disc.disconnect_windows.append(Vector2i(0, 100))
    disc.reset()
    disc.send({"n": 1})
    _check("disconnect window drops at send", int(disc.stats["dropped_disconnect"]) == 1, str(disc.stats))
    _check("desync: first differing tick found", Channel.first_desync_tick(["a", "b", "c"], ["a", "x", "c"]) == 1)
    _check("desync: identical runs stay in sync (-1)", Channel.first_desync_tick(["a", "b"], ["a", "b"]) == -1)
    var clean = Channel.new()
    clean.loss_fraction = 0.0
    clean.latency_ticks = 3
    clean.jitter_ticks = 0
    var ok_run: Dictionary = clean.run_sync_scenario(60)
    _check("clean scenario: no drops", int(ok_run["summary"]["dropped"]) == 0, str(ok_run["summary"]))
    _check("clean scenario: final states match", ok_run["server_final_hash"] == ok_run["client_final_hash"])
    var lossy = Channel.new()
    lossy.loss_fraction = 0.5
    lossy.latency_ticks = 6
    lossy.jitter_ticks = 3
    var bad_run: Dictionary = lossy.run_sync_scenario(180)
    _check("lossy scenario: packets dropped", int(bad_run["summary"]["dropped"]) > 0, str(bad_run["summary"]))
    _check("lossy scenario: inspector flags the loss", _kinds(bad_run["issues"]).has("packet_loss"))
    _finish("MNS TESTS")
