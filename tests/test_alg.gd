extends SceneTree
const Core := preload("res://addons/autoload_graph/core/alg_graph.gd")
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
    var result: Dictionary = op.run("res://demo/autoloads/autoloads.godot")
    check("four autoloads in declared order", result["order"] == ["Audio", "Save", "Events", "Ghost"])
    check("missing ghost script reported", op._count(result, "missing_autoload") == 1)
    check("Audio._ready using later Events flagged", _has(result, "init_order", 5))
    check("Audio <-> Save cycle reported once", op._count(result, "autoload_cycle") == 1)
    check("later-function use is not an init hazard", not _has(result, "init_order", 9))
    var ini: Dictionary = op.parse_ini("[input]\nmove={\n\"deadzone\": 0.5,\n\"events\": []\n}\n[x]\ny=1\n")
    check("multi-line values parsed", ini.has("input/move") and ini.has("x/y") and str(ini["input/move"]["value"]).contains("deadzone"))
    check("real project parses", op.run("res://project.godot")["summary"].has("autoloads"))
    check("missing input is reported", op.run("res://definitely_missing.godot")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/autoloads/autoloads.godot")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Autoload Dependency Graph TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
