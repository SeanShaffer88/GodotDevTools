## GDScript Documentation Generator tests.
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

const Parser := preload("res://addons/doc_gen/core/dcg_parser.gd")


func _init() -> void:
    var op = Parser.new()
    var text := FileAccess.get_file_as_string("res://demo/docs/undocumented.gd")
    var record: Dictionary = op.parse_script(text, "res://demo/docs/undocumented.gd")
    _check("functions parsed with their docs", (record["functions"] as Array).size() == 2, str(record["functions"]))
    var greet_doced := false
    var mystery_bare := false
    for fn in record["functions"]:
        if str((fn as Dictionary)["name"]) == "greet" and not ((fn as Dictionary)["doc"] as Array).is_empty():
            greet_doced = true
        if str((fn as Dictionary)["name"]) == "mystery" and ((fn as Dictionary)["doc"] as Array).is_empty():
            mystery_bare = true
    _check("documented function keeps its comment", greet_doced)
    _check("undocumented function detected (gate kind)", mystery_bare)
    _check("typed args and defaults parsed", str(((record["functions"][1] as Dictionary)["args"][1] as Dictionary)["default"]) == "2", str(record["functions"][1]))
    _check("signals parsed", (record["signals"] as Array).size() == 2, str(record["signals"]))
    var r: Dictionary = op.run([{"path": "res://demo/docs/undocumented.gd", "text": text}])
    var kinds := _kinds(r["issues"])
    _check("run reports the undocumented pair", kinds.has("undocumented") and int(r["summary"]["undocumented"]) == 2, str(r["summary"]))
    var md := op.render_markdown(r)
    _check("markdown renders the greet signature", md.contains("greet(who: String) -> String"), md.substr(0, 400))
    var html := op.render_html(r)
    _check("html renders with a heading", html.begins_with("<!DOCTYPE html>") and html.contains("<h1>"), html.substr(0, 120))
    var project: Dictionary = op.run()
    _check("project scan covers every script", int(project["summary"]["scripts"]) >= 60, str(project["summary"]))
    _check("to_markdown renders coverage", op.to_markdown(project).contains("documented"))
    _finish("GDScript Documentation Generator TESTS")
