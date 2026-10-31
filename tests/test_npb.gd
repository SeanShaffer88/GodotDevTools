extends SceneTree
const Core := preload("res://addons/node_paths/core/npb_checker.gd")
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
    check("weapon muzzle path is broken", _has(result, "broken_path", 16))
    check("existing $Sprite resolves", not _has(result, "broken_path", 14))
    check("%HealthBar unique resolves", op._count(result, "missing_unique") == 0)
    check("get_node(\"Sprite\") resolves", not _has(result, "broken_path", 17))
    check("exactly one broken path in fixture", op._count(result, "broken_path") == 1)
    var refs: Array = op.references("func f():\n\tprint(\"%d\" % 3)\n\t$\"Odd Name\".show()  # $Ghost\n")
    check("format strings and comments are not references", refs.size() == 1 and refs[0]["path"] == "Odd Name")
    var texts := {"res://a.tscn": "[ext_resource type=\"Script\" path=\"res://a.gd\" id=\"1\"]\n[ext_resource type=\"PackedScene\" path=\"res://b.tscn\" id=\"2\"]\n[node name=\"A\" type=\"Node\"]\nscript = ExtResource(\"1\")\n[node name=\"Kid\" parent=\".\" instance=ExtResource(\"2\")]\n",
        "res://b.tscn": "[node name=\"B\" type=\"Node\"]\n[node name=\"Deep\" type=\"Node\" parent=\".\"]\n",
        "res://a.gd": "extends Node\nfunc _ready():\n\t$Kid/Deep.show()\n\t$Kid/Nope.show()\n"}
    var inst: Dictionary = op.analyze(texts)
    check("paths resolve through instanced scenes", op._count(inst, "broken_path") == 1 and inst["issues"][0]["line"] == 4)
    check("unattached scripts skipped by default", op.analyze({"res://x.gd": "func f():\n\t$A.show()\n"})["issues"].is_empty())
    check("unattached scripts reported on request", op.analyze({"res://x.gd": "func f():\n\t$A.show()\n"}, {"report_unattached": true})["issues"][0]["kind"] == "unattached_script")
    check("absolute paths are skipped as dynamic", op.analyze({"res://s.tscn": texts["res://a.tscn"], "res://a.gd": "func f():\n\tget_node(\"/root/Game\")\n"})["summary"]["dynamic_skipped"] == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_npb")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/code_health" if true else "")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Node Path Breakage Detector TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
