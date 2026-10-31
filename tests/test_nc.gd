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

func _init() -> void:
    var audit = Audit.new()
    var result: Dictionary = audit.run("res://demo/naming")
    check("fixture inventories files and directories", result["summary"]["entries"] == 3)
    check("bad file name detected", kinds(result).has("file_name"))
    check("bad directory name detected", kinds(result).has("directory_name"))
    check("only two names flagged", result["issues"].size() == 2)
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
