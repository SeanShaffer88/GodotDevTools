## Android export preset review. Never reads or emits keystore credentials
## other than detecting an explicitly stored password in the preset file.
extends RefCounted

const MAX_BYTES := 2_000_000
const ABI_DEFAULTS := {"armeabi-v7a": false, "arm64-v8a": true, "x86": false, "x86_64": false}


## Read a Godot export_presets.cfg and optional package -> last versionCode JSON.
func run(input: String = "res://export_presets.cfg", options: Dictionary = {}) -> Dictionary:
    var file := FileAccess.open(input, FileAccess.READ)
    if file == null or file.get_length() > MAX_BYTES:
        return _fail(input, "Cannot read the export presets or the file exceeds 2 MB.", "Choose a readable export_presets.cfg under 2 MB.")
    var text: Variant = _read_utf8(file)
    file.close()
    if text == null:
        return _fail(input, "Export presets are not valid UTF-8 text.", "Supply an uncorrupted text export_presets.cfg.")
    var history: Variant = null
    var history_path := str(options.get("history", ""))
    if history_path != "":
        var history_file := FileAccess.open(history_path, FileAccess.READ)
        if history_file == null or history_file.get_length() > MAX_BYTES:
            return _fail(history_path, "Cannot read release history or the file exceeds 2 MB.", "Supply a JSON object of package names to positive version codes.")
        var history_text: Variant = _read_utf8(history_file)
        history_file.close()
        if history_text == null:
            return _fail(history_path, "Release history is not valid UTF-8 text.", "Supply a UTF-8 JSON object without binary data.")
        var parser := JSON.new()
        if parser.parse(str(history_text)) != OK:
            return _fail(history_path, "Release history is not valid JSON.", "Use a UTF-8 JSON object of package names to positive version codes.")
        history = parser.data
        if not _valid_history(history):
            return _fail(history_path, "Release history is not a package-to-positive-integer object.", "Use JSON such as {\"com.studio.game\": 42}.")
    return analyze(str(text), history, input)


func _read_utf8(file: FileAccess) -> Variant:
    var length := file.get_length()
    var bytes := file.get_buffer(length)
    if bytes.size() != length or bytes.has(0):
        return null
    var text := bytes.get_string_from_utf8()
    if text.to_utf8_buffer() != bytes:
        return null
    return text.trim_prefix("\ufeff")


## Analyze preset text without exporting, reading credentials or invoking Gradle.
func analyze(text: String, history: Variant = null, path: String = "") -> Dictionary:
    if history != null and not _valid_history(history):
        return _fail(path, "Release history is not a package-to-positive-integer object.", "Use JSON such as {\"com.studio.game\": 42}.")
    var config := ConfigFile.new()
    if config.parse(text) != OK:
        return _fail(path, "Export presets are not valid ConfigFile text.", "Repair the file and retry.")
    var section_pattern := RegEx.new()
    section_pattern.compile("^preset\\.[0-9]+$")
    var package_regex := RegEx.new()
    package_regex.compile("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$")
    var sections := Array(config.get_sections())
    sections.sort()
    var issues: Array = []
    var rows: Array = []
    for section_value in sections:
        var section := str(section_value)
        if section_pattern.search(section) == null or str(config.get_value(section, "platform", "")) != "Android":
            continue
        var name := str(config.get_value(section, "name", section))
        var opts := section + ".options"
        var package := str(config.get_value(opts, "package/unique_name", "com.example.$genname"))
        var code: Variant = config.get_value(opts, "version/code", 1)
        var gradle_value: Variant = config.get_value(opts, "gradle_build/use_gradle_build", false)
        var signed_value: Variant = config.get_value(opts, "package/signed", true)
        var expansion_value: Variant = config.get_value(opts, "apk_expansion/enable", false)
        var gradle: bool = bool(gradle_value) if typeof(gradle_value) == TYPE_BOOL else false
        var format: Variant = config.get_value(opts, "gradle_build/export_format", 0)
        var output := str(config.get_value(section, "export_path", ""))
        for flag in [["Gradle build", gradle_value], ["signing", signed_value], ["APK expansion", expansion_value]]:
            if typeof(flag[1]) != TYPE_BOOL:
                issues.append(_issue("error", "invalid_option", path, name, "%s must be a boolean." % flag[0], "Use Godot's export preset editor to set this option."))
        var enabled_abis: Array = []
        var malformed_abis := false
        for abi in ABI_DEFAULTS:
            var value: Variant = config.get_value(opts, "architectures/" + abi, ABI_DEFAULTS[abi])
            if typeof(value) != TYPE_BOOL:
                malformed_abis = true
                issues.append(_issue("error", "invalid_architecture", path, name, "An ABI option is not a boolean.", "Use Godot's export preset editor to set the architecture checkboxes."))
            elif value:
                enabled_abis.append(abi)
        if not malformed_abis and enabled_abis.is_empty():
            issues.append(_issue("error", "no_architecture", path, name, "No supported Android architecture is enabled.", "Enable at least one ABI supported by your export templates and devices."))
        if not malformed_abis and "armeabi-v7a" in enabled_abis and "arm64-v8a" not in enabled_abis:
            issues.append(_issue("warning", "arm32_without_arm64", path, name, "The 32-bit ARM ABI is enabled without arm64-v8a.", "Review 64-bit device and distribution requirements for this build."))

        if package_regex.search(package.replace("$genname", "generated")) == null:
            issues.append(_issue("error", "invalid_package", path, name, "The Android package identifier is not valid.", "Use at least two dot-separated segments starting with a letter; $genname is supported."))
        elif package.to_lower() == "com.example" or package.to_lower().begins_with("com.example."):
            issues.append(_issue("warning", "example_package", path, name, "The package uses the example namespace.", "Choose your own stable application ID before publishing."))
        if not _positive_int(code):
            issues.append(_issue("error", "invalid_version_code", path, name, "Android version/code must be a positive integer.", "Set a positive integer version code in the export preset."))
        elif history != null:
            if not history.has(package):
                issues.append(_issue("info", "history_missing", path, name, "No previous version code was supplied for this exact package setting.", "Add the exact package string to the history JSON, or review the published version manually."))
            elif int(code) <= int(history[package]):
                issues.append(_issue("warning", "version_not_increased", path, name, "The version code is not greater than the supplied previous code.", "Increase version/code for the next release of this application ID."))

        var valid_format := typeof(format) == TYPE_INT and int(format) in [0, 1]
        if not valid_format:
            issues.append(_issue("error", "invalid_format", path, name, "The export format is neither APK nor AAB.", "Choose APK or AAB in the Android export preset."))
        elif int(format) == 1 and typeof(gradle_value) == TYPE_BOOL and not gradle:
            issues.append(_issue("error", "bundle_requires_gradle", path, name, "AAB format is selected without Gradle build enabled.", "Enable Gradle build or select APK."))
        if valid_format and output != "":
            var extension := ".aab" if int(format) == 1 else ".apk"
            if not output.ends_with(extension):
                issues.append(_issue("error", "format_extension_mismatch", path, name, "The export filename does not match the selected format.", "Use the matching lowercase .apk or .aab extension."))
        if valid_format and int(format) == 1 and typeof(expansion_value) == TYPE_BOOL and expansion_value:
            issues.append(_issue("error", "bundle_with_expansion", path, name, "APK expansion is enabled for an AAB.", "Disable APK expansion or export an APK instead."))
        if typeof(signed_value) == TYPE_BOOL and not signed_value:
            issues.append(_issue("warning", "unsigned_package", path, name, "Package signing is disabled in this preset.", "For a release, configure signing using a secure keystore and verify the exported artifact."))
        for secret_key in ["keystore/debug_password", "keystore/release_password"]:
            if str(config.get_value(opts, secret_key, "")) != "":
                issues.append(_issue("warning", "embedded_password", path, name, "A keystore password is stored directly in this presets file.", "Remove the secret from shared files and use Godot's protected credentials or environment configuration."))

        var min_sdk := str(config.get_value(opts, "gradle_build/min_sdk", "")).strip_edges()
        var target_sdk := str(config.get_value(opts, "gradle_build/target_sdk", "")).strip_edges()
        if (min_sdk != "" or target_sdk != "") and typeof(gradle_value) == TYPE_BOOL and not gradle:
            issues.append(_issue("warning", "sdk_override_without_gradle", path, name, "SDK overrides are present while Gradle build is disabled.", "Enable Gradle build or remove the ineffective overrides."))
        var invalid_sdk := (min_sdk != "" and (not min_sdk.is_valid_int() or int(min_sdk) < 1 or int(min_sdk) > 2147483647)) or (target_sdk != "" and (not target_sdk.is_valid_int() or int(target_sdk) < 1 or int(target_sdk) > 2147483647))
        if invalid_sdk:
            issues.append(_issue("error", "invalid_sdk", path, name, "An SDK override is not a positive integer.", "Use positive integer SDK levels or leave the override empty."))
        else:
            if min_sdk != "" and int(min_sdk) < 21:
                issues.append(_issue("error", "min_sdk_too_low", path, name, "Minimum SDK is below Godot 4.3's Android library minimum of 21.", "Use at least API 21, and review the renderer and template requirements."))
            # Godot 4.3 uses 24 as the default minimum when checking an explicit target.
            var effective_min := int(min_sdk) if min_sdk != "" else 24
            if target_sdk != "" and int(target_sdk) < effective_min:
                issues.append(_issue("error", "sdk_order", path, name, "Target SDK is lower than the configured or Godot 4.3 default minimum SDK.", "Set target SDK to at least the minimum SDK."))
        rows.append({"name": name, "package": package, "version_code": code if _positive_int(code) else null, "abis": enabled_abis, "format": ("AAB" if int(format) == 1 else "APK") if valid_format else "unknown"})
    if rows.is_empty():
        issues.append(_issue("info", "no_android_preset", path, "", "No Android export preset was found.", "Add an Android preset when you are ready to export for Android."))
    return {"summary": {"android_presets": rows.size(), "issues": issues.size()}, "presets": rows, "issues": issues}


func _positive_int(value: Variant) -> bool:
    if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    var number := float(value)
    return is_finite(number) and number >= 1.0 and number <= 2147483647.0 and floor(number) == number


func _valid_history(history: Variant) -> bool:
    if typeof(history) != TYPE_DICTIONARY:
        return false
    for package in history:
        if typeof(package) != TYPE_STRING or str(package).is_empty() or not _positive_int(history[package]):
            return false
    return true


func _issue(severity: String, kind: String, path: String, preset: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": 0, "preset": preset, "message": ("Preset '%s': " % preset if preset != "" else "") + message, "fix": fix}


func _fail(path: String, message: String, fix: String) -> Dictionary:
    return {"summary": {"android_presets": 0, "issues": 1}, "presets": [], "issues": [_issue("error", "bad_input", path, "", message, fix)]}


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Android Export Readiness", "", "Summary: " + str(result["summary"]), "", "## Findings"]
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
