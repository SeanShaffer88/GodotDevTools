extends SceneTree
const Core := preload("res://addons/unused_symbols/core/usf_finder.gd")
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
    var result: Dictionary = op.run("res://demo/code_health")
    check("never-fired signal reported", _has(result, "never_emitted", 4))
    check("died is emitted and connected", not _has(result, "never_emitted", 3) and not _has(result, "never_connected", 3))
    check("helper never called is unused", _has(result, "unused_function", 30))
    check("connected handler is used", not _has(result, "unused_function", 26))
    check("engine callbacks never flagged", not _has(result, "unused_function", 12))
    var scene_conn: Dictionary = op.analyze({"res://a.gd": "signal hit\nfunc _on_hit():\n\tpass\nfunc go():\n\thit.emit()\n", "res://a.tscn": "[connection signal=\"hit\" from=\".\" to=\".\" method=\"_on_hit\"]\n", "res://b.gd": "func x():\n\tgo()\n"})
    check("scene connections count as connect and use", scene_conn["issues"].filter(func(i): return i["kind"] != "unused_function" or i["line"] != 2).size() == scene_conn["issues"].size() and op._count(scene_conn, "never_connected") == 0)
    check("emit_signal string form counts", op._count(op.analyze({"res://a.gd": "signal s\nfunc f():\n\temit_signal(\"s\")\n\ts.connect(f)\n"}), "never_emitted") == 0)
    check("private functions optional", op._count(op.analyze({"res://a.gd": "func _helper():\n\tpass\n"}, {"include_private": false}), "unused_function") == 0)
    check("call by string counts as a reference", op._count(op.analyze({"res://a.gd": "func boot():\n\tpass\n", "res://b.gd": "func f(n):\n\tn.call(\"boot\")\n"}), "unused_function") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_usf")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/code_health" if true else "")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Unused Signal and Method Finder TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
