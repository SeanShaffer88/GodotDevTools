## Memory Leak and Orphan Hunter tests.
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

const Scanner := preload("res://addons/leak_hunter/core/mlh_scanner.gd")


func _init() -> void:
    var op = Scanner.new()
    var leaky_text := FileAccess.get_file_as_string("res://demo/leaks/leaky.gd")
    var info: Dictionary = op.parse_script(leaky_text, "res://demo/leaks/leaky.gd")
    _check("leaky fixture parses as an orphan risk", bool(info["has_remove_child"]) and not bool(info["has_free"]), str(info))
    var r: Dictionary = op.run()
    var found_orphan := false
    var found_cycle := false
    var found_hold := false
    for i in r["issues"]:
        match str(i["kind"]):
            "orphan_risk":
                if str(i["path"]) == "res://demo/leaks/leaky.gd": found_orphan = true
            "refcount_cycle":
                found_cycle = true
            "signal_hold":
                if str(i["path"]) == "res://demo/leaks/listener.gd": found_hold = true
    _check("orphan risk reported (gate kind)", found_orphan)
    _check("RefCounted circle between the chain fixtures reported", found_cycle)
    _check("signal hold suspect reported", found_hold)
    var synthetic := [op.parse_script("class_name TA\nextends RefCounted\nvar b: TB\n", "a.gd"), op.parse_script("class_name TB\nextends RefCounted\nvar a: TA\n", "b.gd")]
    _check("find_cycles sees the synthetic circle", op.find_cycles(synthetic).size() == 1)
    var clean: Dictionary = op.run([op.parse_script("extends Node\nfunc _ready() -> void:\n\tqueue_free_later()\n", "clean.gd")])
    _check("clean script has no suspects", (clean["issues"] as Array).is_empty(), str(clean["issues"]))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Memory Leak and Orphan Hunter TESTS")
