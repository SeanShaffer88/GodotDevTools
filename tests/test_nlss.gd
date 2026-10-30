## Scene Search tests.
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

const Search := preload("res://addons/scene_search/core/nlss_search.gd")


func _init() -> void:
    var op = Search.new()
    var stats: Dictionary = op.build_index()
    _check("index covers demo files", int(stats["files"]) >= 6, str(stats))
    var terms: Array = op.parse_query("find enemies that use a patrol state")
    _check("query parser keeps content words", terms.has("patrol") and terms.has("state"), str(terms))
    _check("query parser stems enemies -> enemy", terms.has("enemy"), str(terms))
    _check("query parser drops grammar words", not terms.has("find") and not terms.has("that"))
    var r1: Dictionary = op.search("find enemies that use a patrol state")
    _check("patrol search finds results", not (r1["results"] as Array).is_empty(), str(r1["summary"]))
    _check("patrol search ranks the enemy script first", str(r1["results"][0]["path"]) == "res://demo/enemy/enemy.gd", str(r1["results"]))
    _check("results carry reasons", not (r1["results"][0]["reasons"] as Array).is_empty())
    var r2: Dictionary = op.search("show scenes with a door interaction")
    _check("door search finds the door", not (r2["results"] as Array).is_empty() and str(r2["results"][0]["path"]).contains("door"), str(r2["results"]))
    var nonsense := "zx" + "qv" + " nonexist" + "ent th" + "ing"
    var r3: Dictionary = op.search("find the " + nonsense)
    _check("nonsense search returns no results but explains", (r3["results"] as Array).is_empty() and _kinds(r3["issues"]).has("no_results"), str(r3["summary"]))
    _finish("NLSS TESTS")
