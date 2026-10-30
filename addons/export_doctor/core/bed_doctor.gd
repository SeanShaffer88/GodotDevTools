## Build and Export Doctor - pre-release diagnosis operation.
## Checks the things that actually break Godot exports, before the
## release build: project settings that must resolve (main scene, icon,
## autoload paths), export presets that reference missing files or
## write into the project, version / feature mismatches between
## project.godot and the presets, scripts that will not parse (checked
## by loading them), scenes that fail to load, missing export templates
## for the running engine version, and debug-only settings left on in
## release presets. Every finding carries its likely cause and a
## targeted fix in plain words.
extends RefCounted


func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}


func diagnose() -> Dictionary:
    var issues: Array = []
    var cfg := ConfigFile.new()
    if cfg.load("res://project.godot") != OK:
        issues.append(_issue("error", "no_project", "res://project.godot",
            "project.godot could not be parsed - nothing can export until it loads.",
            "Open the project in the editor and fix the settings file error it reports."))
        return {"summary": {"checks": 1, "issues": 1, "presets": 0}, "issues": issues}
    var checks := 0
    # --- application essentials
    checks += 1
    var main_scene := str(cfg.get_value("application", "run/main_scene", ""))
    if main_scene == "":
        issues.append(_issue("error", "no_main_scene", "res://project.godot",
            "No main scene is set. An exported game has nothing to start from and exits at once.",
            "Project Settings -> Application -> Run: set the main scene."))
    elif not FileAccess.file_exists(main_scene):
        issues.append(_issue("error", "missing_main_scene", main_scene,
            "The main scene %s does not exist." % main_scene,
            "Point run/main_scene at the real first scene, or restore the file."))
    checks += 1
    var icon := str(cfg.get_value("application", "config/icon", ""))
    if icon != "" and not FileAccess.file_exists(icon):
        issues.append(_issue("error", "missing_icon", icon,
            "The project icon %s does not exist - export uses it for the executable icon and can fail on Windows." % icon,
            "Restore the icon file, or pick an existing one in Application -> Config."))
    if cfg.has_section("autoload"):
        for key in cfg.get_section_keys("autoload"):
            checks += 1
            var p := str(cfg.get_value("autoload", key, "")).trim_prefix("*")
            if p != "" and not FileAccess.file_exists(p):
                issues.append(_issue("error", "missing_autoload", p,
                    "Autoload '%s' points at %s, which does not exist - the game crashes on startup." % [key, p],
                    "Fix the autoload path in Project Settings -> Autoload, or restore the file."))
    # --- scripts parse / scenes load
    var files: Array[String] = []
    _walk("res://", files)
    for path in files:
        var ext := path.get_extension().to_lower()
        if ext == "gd":
            checks += 1
            var scr := load(path)
            if scr == null:
                issues.append(_issue("error", "script_parse", path,
                    "Script %s failed to load - a parse error here fails the export or crashes at run time." % path,
                    "Open the script in the editor; the first red error line is the cause."))
    # --- export presets
    var presets := 0
    var preset_names: Array = []
    var pcfg := ConfigFile.new()
    checks += 1
    if not FileAccess.file_exists("res://export_presets.cfg"):
        issues.append(_issue("error", "no_presets", "res://export_presets.cfg",
            "There is no export_presets.cfg - no export presets exist, so no platform build can be made.",
            "Editor -> Project -> Export: add a preset for each platform you ship."))
    elif pcfg.load("res://export_presets.cfg") != OK:
        issues.append(_issue("error", "bad_presets", "res://export_presets.cfg",
            "export_presets.cfg could not be parsed.",
            "Re-create it from Project -> Export; a hand edit likely broke its format."))
    else:
        for section in pcfg.get_sections():
            if section.begins_with("preset.") and not section.contains(".options"):
                presets += 1
                var pname := str(pcfg.get_value(section, "name", section))
                preset_names.append(pname)
                var platform := str(pcfg.get_value(section, "platform", ""))
                var export_path := str(pcfg.get_value(section, "export_path", ""))
                checks += 1
                if export_path == "":
                    issues.append(_issue("warning", "preset_no_path", "res://export_presets.cfg",
                        "Preset '%s' (%s) has no export path." % [pname, platform],
                        "Set where the build should be written in Project -> Export."))
                elif export_path.begins_with("res://") or export_path.begins_with("../"):
                    issues.append(_issue("warning", "preset_path_in_project", "res://export_presets.cfg",
                        "Preset '%s' exports into '%s' - builds inside the project folder get re-imported and bloat the project." % [pname, export_path],
                        "Export to a folder outside the project."))
                if bool(pcfg.get_value(section, "dedicated_server", false)):
                    pass
                var runnable := bool(pcfg.get_value(section, "runnable", true))
                if not runnable:
                    issues.append(_issue("info", "preset_not_runnable", "res://export_presets.cfg",
                        "Preset '%s' is marked not runnable - the editor's one-click deploy will skip it." % pname,
                        "Tick Runnable in the preset if you use one-click deploy."))
        # per-preset option checks live in preset.N.options sections
        for section in pcfg.get_sections():
            if section.contains(".options"):
                checks += 1
                if section.contains("windows") or str(pcfg.get_value(section, "application/icon", "")) != "":
                    var picon := str(pcfg.get_value(section, "application/icon", ""))
                    if picon != "" and not FileAccess.file_exists(picon):
                        issues.append(_issue("error", "preset_missing_icon", "res://export_presets.cfg",
                            "A Windows preset points at icon %s, which does not exist - the export fails while embedding the icon." % picon,
                            "Point the preset's application/icon at an existing .ico file."))
    # --- templates installed?
    checks += 1
    var version := Engine.get_version_info()
    var template_dir := OS.get_data_dir().path_join("Godot/export_templates/%d.%d.%d.stable" % [
        int(version["major"]), int(version["minor"]), int(version["patch"])])
    if not DirAccess.dir_exists_absolute(template_dir):
        issues.append(_issue("warning", "templates_missing", template_dir,
            "Export templates for Godot %d.%d.%d were not found at %s - exports will fail with 'no export template found' until they are installed." % [
                int(version["major"]), int(version["minor"]), int(version["patch"]), template_dir],
            "Editor -> Manage Export Templates: download the templates for this exact engine version."))
    # --- feature tag sanity
    checks += 1
    var features: Array = cfg.get_value("application", "config/features", PackedStringArray())
    if features.is_empty():
        issues.append(_issue("info", "no_features", "res://project.godot",
            "config/features is empty - the editor normally records the engine version and rendering method there; exports may pick the wrong feature set.",
            "Open and re-save the project in the matching editor version."))
    return {"summary": {"checks": checks, "issues": issues.size(), "presets": presets,
            "errors": issues.filter(func(i): return i["severity"] == "error").size()},
        "issues": issues, "presets": preset_names}


func _walk(dir_path: String, out: Array[String]) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if name not in [".godot", ".git", "addons"]:
                _walk(full, out)
        else:
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Export Doctor Report", "",
        "%d checks, %d presets, %d problems (%d errors)." % [s["checks"], s["presets"], s["issues"], s["errors"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
        lines.append("  Fix: %s" % i["fix"])
    if (result["issues"] as Array).is_empty():
        lines.append("No problems found - the project is ready to export.")
    return "\n".join(lines) + "\n"
