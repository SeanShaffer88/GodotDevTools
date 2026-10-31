extends SceneTree
const Core := preload("res://addons/font_glyphs/core/fgc_checker.gd")
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
    var result: Dictionary = op.run("res://demo/assets_audit/ascii_only.ttf", {"strings": "res://demo/assets_audit"})
    check("font cmap read (95 ASCII code points)", result["summary"]["font_codepoints"] == 95)
    check("english fully covered", result["locales"]["en"]["missing"] == 0)
    check("german umlauts missing", result["locales"]["de"]["missing"] == 2)
    check("japanese missing", result["locales"]["ja"]["missing"] == 7)
    check("two locales flagged", op._count(result, "missing_glyphs") == 2)
    check("quoted CSV cells parsed", op._csv("k,\"a, b\",\"say \"\"hi\"\"\"")[2] == "say \"hi\"")
    check("po msgstr text collected", op.analyze({"res://fr.po": "msgid \"x\"\nmsgstr \"é\"\n"}, {"covered": {}})["locales"]["fr"]["missing"] == 1)
    check("non-font file rejected", op.run("res://demo/assets_audit/atlas.json")["issues"][0]["kind"] == "bad_font")
    check("missing input is reported", op.run("res://definitely_missing.ttf")["issues"][0]["kind"] == "bad_font")
    var r: Dictionary = op.run("res://demo/assets_audit/ascii_only.ttf", {"strings": "res://demo/assets_audit"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Font Glyph Coverage Checker TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
