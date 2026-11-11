extends SceneTree
const Audit := preload("res://addons/naming_conventions/core/nc_audit.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label)

func kinds(result: Dictionary) -> Array:
    var out: Array = []
    for issue in result["issues"]:
        out.append(issue["kind"])
    return out

func issue_map(result: Dictionary) -> Dictionary:
    var out := {}
    for issue in result["issues"]:
        out[str(issue["path"])] = str(issue["kind"])
    return out


func test_generated_sidecars(audit) -> void:
    # A unique user:// fixture exercises the real filesystem without editing
    # checked-in assets or letting Godot import our deliberately empty files.
    var root := "user://naming_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    var specs: Array = [
        {"path": "good.png", "directory": false},
        {"path": "good.png.import", "directory": false},
        {"path": "BadAsset.png", "directory": false},
        {"path": "BadAsset.png.import", "directory": false},
        {"path": "BadCode.gd", "directory": false},
        {"path": "BadCode.gd.uid", "directory": false},
        {"path": "orphan.svg.import", "directory": false},
        {"path": "orphan.gd.uid", "directory": false},
        {"path": "other.png.IMPORT", "directory": false},
        {"path": "BadSingle.import", "directory": false},
        {"path": "BadSingle.uid", "directory": false},
        {"path": "non_sidecar.bad.ext", "directory": false},
        {"path": "Bad.folder.import", "directory": true},
        {"path": "Bad.folder.import/good_child.txt", "directory": false},
        {"path": "Bad.script.uid", "directory": true},
        {"path": "Bad.script.uid/BadChild.gd", "directory": false},
    ]
    var entries: Array = []
    # mkdir must create a new directory; never reuse or delete an existing one.
    var made_root := DirAccess.make_dir_absolute(ProjectSettings.globalize_path(root)) == OK
    check("unique sidecar fixture directory created", made_root)
    if not made_root:
        return
    var created := true
    for spec in specs:
        var full := root.path_join(str(spec["path"]))
        var directory := bool(spec["directory"])
        entries.append({"path": full, "directory": directory})
        if directory:
            if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(full)) != OK:
                created = false
        else:
            var file := FileAccess.open(full, FileAccess.WRITE)
            if file == null:
                created = false
            else:
                file.store_string("test fixture")
                file.close()
    check("filesystem sidecar fixture created", created)
    if created:
        var expected := {}
        for path in ["BadAsset.png", "BadCode.gd", "BadSingle.import", "BadSingle.uid", "non_sidecar.bad.ext", "Bad.script.uid/BadChild.gd"]:
            expected[root.path_join(path)] = "file_name"
        for path in ["Bad.folder.import", "Bad.script.uid"]:
            expected[root.path_join(path)] = "directory_name"
        var scanned: Dictionary = audit.run(root)
        var analyzed: Dictionary = audit.analyze(entries)
        check("filesystem scan skips generated and orphaned sidecar files", scanned["summary"]["entries"] == 10)
        check("explicit entries skip generated and orphaned sidecar files", analyzed["summary"]["entries"] == 10)
        check("filesystem scan still checks sources, single extensions and sidecar-named directories", issue_map(scanned) == expected)
        check("explicit entries have the same findings as filesystem scan", issue_map(analyzed) == expected)
        check("invalid-pattern summary excludes explicit sidecars", audit.analyze(entries, "[")["summary"]["entries"] == 10)
    # Remove children before parents; the unique directory has no outside data.
    for index in range(specs.size() - 1, -1, -1):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join(str(specs[index]["path"]))))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(root))


func _init() -> void:
    var audit = Audit.new()
    var result: Dictionary = audit.run("res://demo/naming")
    check("fixture inventories files and directories", result["summary"]["entries"] == 3)
    check("bad file name detected", kinds(result).has("file_name"))
    check("bad directory name detected", kinds(result).has("directory_name"))
    check("only two names flagged", result["issues"].size() == 2)
    test_generated_sidecars(audit)
    var clean: Dictionary = audit.analyze([{"path": "res://levels/start_menu.tscn", "directory": false}])
    check("snake case file passes", clean["issues"].is_empty())
    var custom: Dictionary = audit.analyze([{"path": "res://MyScene.tscn", "directory": false}], "^[A-Z][A-Za-z]*$")
    check("custom regular expression supported", custom["issues"].is_empty())
    check("invalid regex reported", kinds(audit.analyze([], "[" )).has("invalid_pattern"))
    check("missing root reported", kinds(audit.run("res://missing_naming_fixture_dir")).has("scan_error"))
    var symbol_result: Dictionary = audit.run("res://demo/naming_symbols", ".*", true)
    check("bad scene node detected", kinds(symbol_result).has("node_name"))
    check("bad signal detected", kinds(symbol_result).has("signal_name"))
    check("scene and script groups detected", kinds(symbol_result).count("group_name") == 2)
    check("only intended symbol violations found", symbol_result["issues"].size() == 4 and symbol_result["summary"]["issues"] == 4)
    check("symbols remain opt-in", audit.run("res://demo/naming_symbols", ".*")["issues"].is_empty())
    var flexible: Dictionary = audit.run("res://demo/naming_symbols", ".*", true, {"node_name": "^[A-Za-z_]+$", "signal_name": "^[A-Za-z_]+$", "group_name": "^[A-Za-z_]+$"})
    check("custom symbol patterns supported", flexible["issues"].is_empty())
    check("invalid symbol pattern rejected", kinds(audit.run("res://demo/naming_symbols", Audit.DEFAULT_PATTERN, true, {"node_name": "["})).has("invalid_pattern"))
    check("symbol findings include line numbers", str(symbol_result["issues"][0]["path"]).contains(":"))
    check("markdown has finding", audit.to_markdown(result).contains("BadName"))
    check("JSON has issues", JSON.parse_string(audit.to_json(result)).has("issues"))
    print("Naming Conventions TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
