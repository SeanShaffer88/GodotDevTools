extends SceneTree
const Core := preload("res://addons/atlas_planner/core/atp_planner.gd")
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

func _no_overlap(placements: Array, _r: Dictionary) -> bool:
    var seen := {}
    for p in placements:
        var key := "%d:%d:%d" % [p["page"], p["x"], p["y"]]
        if seen.has(key):
            return false
        seen[key] = true
    return true

func _init() -> void:
    var result: Dictionary = op.run("res://demo/assets_audit/atlas.json")
    check("JSON page size used", result["summary"]["page_size"] == 256)
    check("oversize background reported", op._count(result, "sprite_too_big") == 1)
    check("tiles and bar need two pages", result["summary"]["pages"] == 2)
    check("waste reported", op._count(result, "high_waste") == 1)
    check("page budget enforced", op._count(op.run("res://demo/assets_audit/atlas.json", {"max_pages": 1}), "page_budget") == 1)
    check("no overlaps on a page", _no_overlap(result["placements"], op.run("res://demo/assets_audit/atlas.json")))
    var png: Dictionary = op.run("res://demo/assets_audit/pixel")
    check("PNG headers read", png["summary"]["sprites"] == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/assets_audit/atlas.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Texture Atlas Packing Planner TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
