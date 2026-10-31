extends SceneTree
const Core := preload("res://addons/ability_sim/core/gas_simulator.gd")
var op = Core.new()
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _has(result: Dictionary, kind: String, line: int) -> bool:
    for issue in result["issues"]:
        if issue["kind"] == kind and int(issue["line"]) == line:
            return true
    return false

func _init() -> void:
    var result: Dictionary = op.run("res://demo/gameplay/abilities.json")
    var rows := {}
    for r in result["abilities"]:
        rows[r["id"]] = r
    check("meteor never castable", op._count(result, "never_castable") == 1 and rows["meteor"]["casts"] == 0)
    check("frost cooldown below its cast", op._count(result, "cooldown_below_cast") == 1)
    check("free instant zap flagged", op._count(result, "instant_spam") == 1)
    check("cheap frost spends the mana fireball needs", rows["fireball"]["casts"] >= 1 and rows["frost"]["casts"] > rows["fireball"]["casts"])
    check("filler keeps idle time low", float(result["summary"]["idle_share"]) < 0.05 and op._count(result, "starved") == 0)
    check("dps reported", float(result["summary"]["dps"]) > 0.0)
    var starve: Dictionary = op.evaluate({"duration": 10, "resources": {"rage": {"max": 10, "start": 0, "regen": 1}}, "abilities": [{"id": "slam", "cost": {"rage": 10}, "cooldown": 0, "cast_time": 0, "damage": 5}]})
    check("resource starvation detected", op._count(starve, "starved") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/gameplay/abilities.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Gameplay Ability Simulator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
