extends SceneTree
const Core := preload("res://addons/a11y_options/core/aoc_coverage.gd")
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
    var result: Dictionary = op.run("res://demo/shipping")
    check("four of seven options evidenced", result["summary"]["found"] == 4)
    check("subtitles found in the options script", str(result["evidence"]["subtitles"]).contains("options_menu.gd"))
    check("colour-blind, mono and hold-toggle missing", op._count(result, "option_not_found") == 3)
    check("custom list replaces defaults", op.analyze({"res://a.gd": "var big_cursor = true"}, {"expect_list": [{"id": "cursor", "patterns": ["big_cursor"]}]})["summary"]["found"] == 1)
    check("bad list rejected", op.run("res://demo/shipping", {"expect": "res://nope.json"})["issues"][0]["kind"] == "bad_input")
    check("missing input is reported", op.run("res://definitely_missing_dir_aoc")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/shipping")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)

    var anchored := [{"id": "anchor", "patterns": ["^caption$"]}]
    var anchored_result: Dictionary = op.analyze({"res://a.gd": "first\ncaption\nlast"}, {"expect_list": anchored})
    check("line anchors work in whole-file search", anchored_result["evidence"].get("anchor", "") == "res://a.gd:2")
    var backref := [{"id": "repeat", "patterns": ["late", "(early)\\s+\\1"]}]
    var backref_result: Dictionary = op.analyze({"res://a.gd": "early early\nlate"}, {"expect_list": backref})
    check("multiple patterns keep backreferences and earliest line", backref_result["evidence"].get("repeat", "") == "res://a.gd:1")

    var cache_path := "user://aoc_cache_test_%s.json" % str(OS.get_process_id())
    if FileAccess.file_exists(cache_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
    var expected := [{"id": "subtitle", "patterns": ["subtitles"]}]
    var texts := {"res://a.gd": "before\nsubtitles", "res://b.gd": "subtitles"}
    var first: Dictionary = op._run_cached(texts, expected, cache_path)
    check("cache records the first sorted evidence", first["evidence"].get("subtitle", "") == "res://a.gd:2")
    var repeated: Dictionary = op._run_cached(texts, expected, cache_path)
    check("unchanged files are reused", repeated["summary"].get("cached_files", 0) == 2 and repeated["evidence"] == first["evidence"])
    texts["res://a.gd"] = "no evidence"
    var edited: Dictionary = op._run_cached(texts, expected, cache_path)
    var fresh: Dictionary = op.analyze(texts, {"expect_list": expected})
    check("unchanged later file supplies evidence after edit", edited["evidence"] == fresh["evidence"] and edited["evidence"].get("subtitle", "") == "res://b.gd:1" and edited["summary"].get("cached_files", 0) == 1)
    texts.erase("res://a.gd")
    var deleted: Dictionary = op._run_cached(texts, expected, cache_path)
    check("deleting a file preserves evidence from unchanged files", deleted["evidence"].get("subtitle", "") == "res://b.gd:1")
    texts["res://a.gd"] = "subtitles"
    var added: Dictionary = op._run_cached(texts, expected, cache_path)
    check("new earlier file takes precedence", added["evidence"].get("subtitle", "") == "res://a.gd:1")
    var changed_expected := [{"id": "subtitle", "patterns": ["captions"]}]
    var changed: Dictionary = op._run_cached(texts, changed_expected, cache_path)
    var changed_fresh: Dictionary = op.analyze(texts, {"expect_list": changed_expected})
    check("changing patterns invalidates cached evidence", changed["evidence"] == changed_fresh["evidence"] and changed["issues"] == changed_fresh["issues"] and changed["summary"].get("cached_files", -1) == 0)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))

    var scan_dir := "user://aoc_scan_test_%s" % str(OS.get_process_id())
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scan_dir))
    var source := scan_dir.path_join("options.gd")
    var local_cache := scan_dir.path_join("cache.json")
    var file := FileAccess.open(source, FileAccess.WRITE)
    file.store_string("subtitles")
    file.close()
    op.run(scan_dir, {"cache": local_cache})
    file = FileAccess.open(source, FileAccess.WRITE)
    file.store_string("no evidence")
    file.close()
    var excluded_cache: Dictionary = op.run(scan_dir, {"cache": local_cache})
    check("cache inside scan root is not scanned as evidence", not excluded_cache.get("evidence", {}).has("subtitles"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(source))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(local_cache))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(scan_dir))
    print("Accessibility Options Coverage TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
