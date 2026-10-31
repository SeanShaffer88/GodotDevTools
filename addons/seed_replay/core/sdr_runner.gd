## Deterministic Seed and Replay Runner - replay verification operation.
## The trust half of deterministic runs: a hand-rolled 31-bit LCG PRNG
## (identical sequence on every platform and engine version, unlike
## trusting randf() internals) and an FNV-1a checksum over UTF-8 bytes.
## A run log records the seed, every PRNG value consumed and a chain of
## event hashes; verify() re-runs the LCG from the seed and recomputes
## the chain, reporting the first divergence (mismatch), a broken event
## chain (chain_break), and structural problems (errors). When a "same
## seed, different outcome" bug report arrives, this answers in seconds:
## either the PRNG diverged (someone consumed randomness off-log) or the
## events diverged (game logic is non-deterministic). runtime/sdr_rng.gd
## records logs from a live game; this file is pure data in, verdict out.
extends RefCounted

const LCG_MOD: int = 0x7FFFFFFF
const LCG_A: int = 1103515245
const LCG_C: int = 12345
const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619


## One LCG step: [value, next_state]. 31-bit space, no 64-bit wrap
## ambiguity, so any language can reproduce the sequence exactly.
func lcg_step(state: int) -> Array:
    var next_state := (state * LCG_A + LCG_C) & LCG_MOD
    return [float(next_state) / float(LCG_MOD), next_state]


func lcg_sequence(seed_value: int, count: int) -> Array:
    var out: Array = []
    var state := seed_value & LCG_MOD
    for i in count:
        var step := lcg_step(state)
        out.append(step[0])
        state = int(step[1])
    return out


## FNV-1a, 32-bit, over UTF-8 bytes.
func fnv1a(text: String) -> int:
    var h := FNV_OFFSET
    for byte in text.to_utf8_buffer():
        h = h ^ byte
        h = (h * FNV_PRIME) & 0xFFFFFFFF
    return h


func event_hash(prev_hash: int, event: Dictionary) -> int:
    return fnv1a("%d|%s|%s" % [prev_hash, str(event.get("kind", "")), str(event.get("data", ""))])


func load_run_log(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"errors": [{"severity": "error", "kind": "errors", "path": path,
            "message": "Run log not found: %s" % path,
            "fix": "Record one with runtime/sdr_rng.gd (save_run_log), or check the path."}],
            "log": {}}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("seed"):
        return {"errors": [{"severity": "error", "kind": "errors", "path": path,
            "message": "%s is not a run log (no seed)." % path,
            "fix": "Re-record; the file is damaged or was not written by the seed runner."}],
            "log": {}}
    return {"errors": [], "log": parsed}


## The one operation: verify a run log by replaying its seed and
## recomputing its event chain.
func verify(run_log: Dictionary) -> Dictionary:
    var issues: Array = []
    var seed_value := int(run_log.get("seed", 0))
    var consumed: Array = run_log.get("prng", [])
    var replay := lcg_sequence(seed_value, consumed.size())
    var first_mismatch := -1
    for i in consumed.size():
        var recorded := float(consumed[i])
        var expected := float(replay[i])
        if absf(recorded - expected) > 0.0000001:
            first_mismatch = i
            issues.append({"severity": "error", "kind": "mismatch", "path": "prng[%d]" % i,
                "message": "PRNG call #%d consumed %s but seed %d deterministically produces %s - something rolled dice off the log." % [
                    i, _fmt(recorded), seed_value, _fmt(expected)],
                "fix": "Find randf/randi calls that do not go through the recorded RNG (scene autoloads and particles are common culprits) and route them through it."})
            break
    var events: Array = run_log.get("events", [])
    var chain := int(run_log.get("chain_start", 0))
    var recomputed := chain
    for i in events.size():
        var ev: Dictionary = events[i]
        recomputed = event_hash(recomputed, ev)
        var recorded_hash := int(ev.get("hash", -1))
        if recorded_hash >= 0 and recorded_hash != recomputed:
            issues.append({"severity": "error", "kind": "chain_break", "path": "events[%d]" % i,
                "message": "Event #%d ('%s') hashes to %d from the chain, but the log recorded %d - the event stream diverged here." % [
                    i, str(ev.get("kind", "")), recomputed, recorded_hash],
                "fix": "Everything after this event is suspect. Compare logic that produced this event: dictionary order, physics timing and OS clocks are the usual non-determinism."})
            break
    var diverged := first_mismatch >= 0 or not issues.is_empty()
    return {"summary": {"seed": seed_value, "prng_calls": consumed.size(),
            "events": events.size(), "first_mismatch": first_mismatch,
            "chain_end": recomputed, "verdict": "diverged" if diverged else "deterministic",
            "issues": issues.size()},
        "issues": issues}


func _fmt(v: float) -> String:
    return "%.7f" % v


func run(run_log: Dictionary) -> Dictionary:
    return verify(run_log)


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Seed Replay Report", "",
        "Seed %d: %d PRNG calls, %d events. Verdict: %s. %d problems." % [
            s["seed"], s["prng_calls"], s["events"], s["verdict"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
