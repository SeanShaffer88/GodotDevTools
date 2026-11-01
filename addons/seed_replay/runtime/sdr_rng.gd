## Deterministic Seed and Replay Runner - in-game recorded RNG.
## Drop-in deterministic randomness: reseed(n) once at run start, then
## every randf()/randi_range() call goes through the core's 31-bit LCG
## and lands in the log. Game events join the log through log_event(),
## which extends the FNV-1a hash chain the verifier recomputes.
## save_run_log() writes the exact JSON the runner core verifies, so a
## player's "same seed, different run" report becomes a one-command
## answer: either the PRNG diverged (something rolled dice off this
## node) or the event chain broke (game logic is non-deterministic).
## Autoload it as DetRNG and route gameplay randomness through it.
extends Node

const Runner := preload("res://addons/seed_replay/core/sdr_runner.gd")

## Set false to consume randomness without recording (e.g. cosmetics).
@export var recording: bool = true

var runner = Runner.new()
var seed_value: int = 1

var _state: int = 1
var _prng: Array = []
var _events: Array = []
var _chain: int = 0


## Start (or restart) a recorded run from a seed.
func reseed(new_seed: int) -> void:
    seed_value = new_seed
    _state = new_seed & Runner.LCG_MOD
    _prng = []
    _events = []
    _chain = 0


func randf() -> float:
    var step := runner.lcg_step(_state)
    _state = int(step[1])
    if recording:
        _prng.append(step[0])
    return float(step[0])


func randf_range(from: float, to: float) -> float:
    # self. is required: a bare randf() resolves to the engine's global,
    # unseeded randf(), which silently breaks replay.
    return lerpf(from, to, self.randf())


func randi_range(from: int, to: int) -> int:
    if to <= from:
        return from
    return from + int(self.randf() * float(to - from + 1)) % (to - from + 1)


## Add an event to the hash chain: kind plus any data worth pinning
## (positions as fixed-precision strings, never floats with full
## precision - the chain must be reproducible from the log alone).
func log_event(kind: String, data: String = "") -> int:
    var hash := runner.event_hash(_chain, {"kind": kind, "data": data})
    if recording:
        _events.append({"kind": kind, "data": data,
            "t_usec": Time.get_ticks_usec(), "hash": hash})
    _chain = hash
    return hash


## The log in the verifier's shape.
func run_log() -> Dictionary:
    return {"seed": seed_value, "chain_start": 0, "prng": _prng, "events": _events}


func save_run_log(path: String = "user://run_log.json") -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(run_log(), "\t"))
    f.close()
    return true


## Self-check: verify this node's own log (must always come back
## deterministic - a failure here is a bug in the runner itself).
func verify_self() -> Dictionary:
    return runner.verify(run_log())
