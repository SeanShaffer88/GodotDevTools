## Tilemap Rule Generator tests.
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

const Rules := preload("res://addons/tilemap_rules/core/tmr_rules.gd")


func _init() -> void:
    var op = Rules.new()
    _check("opposite of right is left", op.opposite_bit(3) == 7)
    _check("corner zero flanks are top and left", (op.neighbour_bits(0) as Array) == [1, 7], str(op.neighbour_bits(0)))
    var by_name: Dictionary = op.tile_peering({"name": "t", "peering": {"right": "sand"}})
    _check("peering accepts named bits", str(by_name[3]) == "sand" and str(by_name[7]) == "", str(by_name))
    var rules = JSON.parse_string(FileAccess.get_file_as_string("res://demo/tilemap/rules.json"))
    var r: Dictionary = op.run(rules)
    var kinds := _kinds(r["issues"])
    _check("one-way grass/sand edge flagged (gate kind)", kinds.has("asymmetric_rule"), str(r["issues"]))
    _check("water pairs with no transitions flagged", kinds.has("missing_transition"))
    _check("generation covers every ordered pair and side", (r["specs"] as Array).size() == 24, str((r["specs"] as Array).size()))
    var corner_rule := {"terrains": ["a", "b"], "tiles": [{"name": "odd_corner", "peering": {"0": "b", "1": "a", "2": "a", "3": "a", "4": "a", "5": "a", "6": "a", "7": "a"}}]}
    _check("corner against both flanking sides flagged", _kinds(op.run(corner_rule)["issues"]).has("corner_conflict"))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Tilemap Rule Generator TESTS")
