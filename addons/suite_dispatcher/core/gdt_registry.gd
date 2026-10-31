## Suite CLI Dispatcher - one entry point.
## Discovers tools as addon folders with a plugin.cfg and a cli/*_cli.gd
## script. `gdt.gd -- list` prints them; `gdt.gd -- run <tool> [options]`
## runs that tool's CLI in a child Godot process with the options passed
## through and exits with its exit code; `gdt.gd -- all` runs every CLI with
## defaults and exits 2 if any did. Tools never depend on the dispatcher.
extends RefCounted

const EXTS: Array[String] = ["cfg"]
const DEFAULTS := {}


func run(input: String = "res://addons", options: Dictionary = {}) -> Dictionary:
    var dir := DirAccess.open(input)
    if dir == null:
        return _fail(input, "Addons folder not found.", "Pass --addons=<folder>.", "bad_input")
    var tools := {}
    var issues: Array = []
    for name in dir.get_directories():
        var base := input.path_join(name)
        if not FileAccess.file_exists(base.path_join("plugin.cfg")):
            continue
        var cli_dir := DirAccess.open(base.path_join("cli"))
        var cli := ""
        if cli_dir != null:
            for f in cli_dir.get_files():
                if f.ends_with("_cli.gd") and cli == "":
                    cli = base.path_join("cli").path_join(f)
        var title := name
        for line in FileAccess.get_file_as_string(base.path_join("plugin.cfg")).split("\n"):
            if line.begins_with("name="):
                title = line.trim_prefix("name=").trim_prefix("\"").trim_suffix("\"")
        if cli == "":
            issues.append(_issue("info", "missing_cli", base, 0, "%s has no cli/*_cli.gd." % title, "Only tools with a headless CLI can be dispatched."))
            continue
        tools[name] = {"title": title, "cli": cli}
    return _finish({"tools": tools.size()}, issues, {"tools": tools})


## Resolve a tool by exact folder name, else a unique prefix; "" when unknown or ambiguous.
func resolve(tools: Dictionary, name: String) -> String:
    if tools.has(name):
        return name
    var hits: Array = tools.keys().filter(func(k): return str(k).begins_with(name))
    return hits[0] if hits.size() == 1 else ""


## Run one CLI in a child process; returns its exit code.
func dispatch(cli: String, args: Array) -> int:
    var argv: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", cli, "--"]
    argv.append_array(args)
    var output: Array = []
    var code := OS.execute(OS.get_executable_path(), PackedStringArray(argv), output, true)
    for chunk in output:
        printraw(str(chunk))
    return code


func _walk(path: String, out: Array) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not name.begins_with(".") and name not in ["addons", "reports", "visual_reports"]:
            var child := path.path_join(name)
            if dir.current_is_dir():
                _walk(child, out)
            elif name.get_extension().to_lower() in EXTS:
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()


func _opts(options: Dictionary) -> Dictionary:
    var merged: Dictionary = DEFAULTS.duplicate(true)
    merged.merge(options, true)
    return merged


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))


func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}


func _fail(path: String, message: String, fix: String, kind: String = "scan_error") -> Dictionary:
    return {"summary": {"issues": 1}, "issues": [_issue("error", kind, path, 0, message, fix)]}


func _finish(summary: Dictionary, issues: Array, extra: Dictionary = {}) -> Dictionary:
    issues.sort_custom(func(a, b): return "%s|%08d|%s" % [a["path"], int(a["line"]), a["kind"]] < "%s|%08d|%s" % [b["path"], int(b["line"]), b["kind"]])
    summary["issues"] = issues.size()
    var result := {"summary": summary, "issues": issues}
    result.merge(extra)
    return result


func _count(result: Dictionary, kind: String) -> int:
    var n := 0
    for issue in result["issues"]:
        if issue["kind"] == kind:
            n += 1
    return n


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array = ["# Suite CLI Dispatcher", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
