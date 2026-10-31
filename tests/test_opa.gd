extends SceneTree
const Advisor := preload("res://addons/pool_advisor/core/opa_advisor.gd")
const Counter := preload("res://addons/pool_advisor/runtime/opa_counter.gd")
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _kinds(result: Dictionary) -> Array:
    var out: Array = []
    for issue in result["issues"]:
        out.append(issue["kind"])
    return out

func _init() -> void:
    var op = Advisor.new()
    var result: Dictionary = op.run("res://demo/pooling")
    check("three spawn sites found in the gun", result["summary"]["spawn_sites"] == 3)
    var bullet: Dictionary = result["scenes"][0]
    check("self-freeing bullet ranks first", bullet["scene"] == "res://demo/pooling/bullet.tscn" and bullet["self_frees"])
    check("per-frame + self-free bullet is a pool candidate", result["summary"]["candidates"] == 1 and "pool_candidate" in _kinds(result))
    check("crate loop in _ready is only a burst", "burst_spawn" in _kinds(result))
    check("unknown PackedScene var is unresolved", "unresolved_spawn" in _kinds(result))
    var sites: Array = op.parse_script(FileAccess.get_file_as_string("res://demo/pooling/gun.gd"))
    check("timer-connected handler counts as warm", sites[2]["function"] == "_reload" and sites[2]["context"] == "warm")
    check("root script detected from scene", op.root_script(FileAccess.get_file_as_string("res://demo/pooling/bullet.tscn")) == "res://demo/pooling/bullet.gd")
    check("x.queue_free() on another node is not self-free", not op.script_frees_self("func f(n):\n\tn.queue_free()\n"))
    var counts: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://demo/pooling/counts.json"))
    var measured: Dictionary = op.run("res://demo/pooling", counts)
    check("recorded rate raises bullet score", measured["scenes"][0]["score"] == bullet["score"] + 3 and is_equal_approx(float(measured["scenes"][0]["rate"]), 15.0))
    check("high spawn rate reported only above threshold", _kinds(measured).count("high_spawn_rate") == 1)
    check("malformed counts rejected", "bad_counts" in _kinds(op.analyze({}, {"seconds": 0, "scenes": {}})))
    check("direct preload().instantiate() resolved", op.parse_script("func spawn():\n\tadd_child(preload(\"res://x.tscn\").instantiate())\n")[0]["target"] == "res://x.tscn")
    check("unreadable file is an error", op.analyze({"res://a.gd": null})["issues"][0]["kind"] == "scan_error")
    check("missing directory is an error", op.run("res://definitely_missing_pool")["issues"][0]["kind"] == "scan_error")
    var counter = Counter.new()
    counter.record("res://demo/pooling/bullet.tscn", "spawned")
    counter.record("res://demo/pooling/bullet.tscn", "spawned")
    counter.record("res://demo/pooling/bullet.tscn", "freed")
    counter.record("", "spawned")
    var snap: Dictionary = counter.snapshot(2.0)
    check("runtime counter snapshot feeds the advisor", op.rates_from_counts(snap, [])["res://demo/pooling/bullet.tscn"]["rate"] == 1.0)
    counter.record("res://demo/pooling/bullet.tscn", "spawn")
    check("unknown counter field is ignored, not a script error", counter.snapshot(1.0)["scenes"]["res://demo/pooling/bullet.tscn"]["spawned"] == 2)
    counter.enabled = false
    counter.record("res://demo/pooling/bullet.tscn", "spawned")
    check("disabled counter records nothing", counter.snapshot(1.0)["scenes"]["res://demo/pooling/bullet.tscn"]["spawned"] == 2)
    counter.free()
    check("markdown lists the bullet", op.to_markdown(result).contains("bullet.tscn"))
    check("json parses", JSON.parse_string(op.to_json(result)).has("scenes"))
    print("Pool Advisor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
