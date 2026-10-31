extends SceneTree
## Gameplay Scenario Test Builder CLI: runs one scenario JSON in this headless process.
##   godot --headless --path . --script res://addons/scenario_tests/cli/gsb_cli.gd -- --scenario=<json> [--out=<dir>] [--fail-on=assertion_failed,step_error]
## Exit 2 when a --fail-on kind is found; 1 for an invalid scenario or report-write failure.
const Core := preload("res://addons/scenario_tests/core/gsb_scenario.gd")
const Runner := preload("res://addons/scenario_tests/runtime/gsb_runner.gd")

var _runner
var _fail_on: Array = []
var _out := "res://reports/scenario_tests"
var _path := ""
var _frames := 0


func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--scenario="):
            _path = arg.trim_prefix("--scenario=")
        elif arg.begins_with("--out="):
            _out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            _fail_on = Array(arg.trim_prefix("--fail-on=").split(",", false))
        else:
            printerr("Unknown argument: ", arg)
            quit(1)
            return
    var core = Core.new()
    var data: Variant = core._read_json(_path)
    if typeof(data) != TYPE_DICTIONARY:
        printerr("Scenario missing or not a JSON object: ", _path)
        quit(1)
        return
    var problems: Array = core.validate(data, _path)
    if not problems.is_empty():
        for p in problems:
            printerr(p["message"])
        quit(1)
        return
    _runner = Runner.new()
    root.add_child(_runner)
    _runner.start(data)
    process_frame.connect(_poll)


func _poll() -> void:
    _frames += 1
    if not _runner.done and _frames < 36000:
        return
    process_frame.disconnect(_poll)
    var core = Core.new()
    var result: Dictionary = core.evaluate(_runner.results, _path)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
    for pair in [["scenario_tests.json", core.to_json(result)], ["scenario_tests.md", core.to_markdown(result)]]:
        var f := FileAccess.open(_out.path_join(pair[0]), FileAccess.WRITE)
        if f == null:
            printerr("Cannot write report: ", _out.path_join(pair[0]))
            quit(1)
            return
        f.store_string(pair[1])
    print("Gameplay Scenario Test Builder: ", result["summary"])
    var failed := false
    for i in result["issues"]:
        print("[%s] step %s: %s" % [i["kind"], i["line"], i["message"]])
        if i["kind"] in _fail_on or "issues" in _fail_on or "errors" in _fail_on:
            failed = true
    quit(2 if failed else 0)
