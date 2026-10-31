extends SceneTree
const Core := preload("res://addons/crafting_graph/core/cgv_validator.gd")
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
    var result: Dictionary = op.run("res://demo/balance/crafting.json")
    check("four of six recipes can run", result["summary"]["recipes_reachable"] == 4)
    check("amulet goal unobtainable", op._count(result, "unobtainable_goal") == 1)
    check("moonstone has no source", op._count(result, "missing_input") == 1)
    check("elixir only bootstraps itself", op._count(result, "self_bootstrapping") == 1)
    check("sawdust is a dead end", op._count(result, "dead_end") == 1)
    check("sword obtainable", "sword" in result["obtainable"])
    check("duplicate recipe ids flagged", op._count(op.evaluate({"base_items": [], "recipes": [{"id": "a", "inputs": {}, "outputs": {}}, {"id": "a", "inputs": {}, "outputs": {}}]}), "duplicate_recipe") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/crafting.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Crafting and Inventory Graph Validator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
