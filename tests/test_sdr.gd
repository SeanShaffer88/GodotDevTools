## Deterministic Seed and Replay Runner tests.
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

const Runner := preload("res://addons/seed_replay/core/sdr_runner.gd")


func _init() -> void:
    var op = Runner.new()
    var seq1: Array = op.lcg_sequence(12345, 8)
    var seq2: Array = op.lcg_sequence(12345, 8)
    _check("LCG replays identically from a seed", seq1 == seq2)
    _check("LCG values stay in unit range", float(seq1[0]) >= 0.0 and float(seq1[0]) < 1.0)
    _check("LCG matches the reference first value", absf(float(seq1[0]) - 0.655154049) < 0.0000001, str(seq1[0]))
    _check("FNV-1a of empty text is the offset basis", op.fnv1a("") == 2166136261)
    _check("FNV-1a matches the known test vector", op.fnv1a("a") == 3826002220, str(op.fnv1a("a")))
    var loaded := op.load_run_log("res://demo/seeds/run_log.json")
    _check("fixture log loads", (loaded["errors"] as Array).is_empty(), str(loaded["errors"]))
    var ok: Dictionary = op.verify(loaded["log"])
    _check("recorded run verifies deterministic", str(ok["summary"]["verdict"]) == "deterministic" and (ok["issues"] as Array).is_empty(), str(ok))
    var tampered := op.load_run_log("res://demo/seeds/tampered_log.json")
    var bad: Dictionary = op.verify(tampered["log"])
    _check("tampered log pinpoints the mismatch (gate kind)", _kinds(bad["issues"]).has("mismatch") and int(bad["summary"]["first_mismatch"]) == 4, str(bad))
    var broken_chain := op.load_run_log("res://demo/seeds/run_log.json")
    var blog: Dictionary = (broken_chain["log"] as Dictionary).duplicate(true)
    (blog["events"][1] as Dictionary)["data"] = "goblin:4,7->9,9"
    var chain_result: Dictionary = op.verify(blog)
    _check("edited event breaks the hash chain", _kinds(chain_result["issues"]).has("chain_break"), str(chain_result))
    _check("to_markdown prints the verdict", op.to_markdown(ok).contains("deterministic"))
    _finish("Deterministic Seed and Replay Runner TESTS")
