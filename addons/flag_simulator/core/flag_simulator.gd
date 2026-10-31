## Offline simulation only. Never sends identifiers or changes configuration.
extends RefCounted

func run(path: String, subject: String, available: bool = true) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _result({}, [_issue("error", "input_error", path, "Cannot open flag configuration.", "Choose a readable JSON configuration.")])
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return _result({}, [_issue("error", "input_error", path, "Configuration must be a JSON object.", "Provide valid JSON with a flags object.")])
    return simulate(parser.data, subject, available)

## The bucket is stable across runs, not cryptographic or appropriate for identity protection.
func bucket(flag_name: String, subject: String) -> int:
    var value := 5381
    for byte in (flag_name + "\u001f" + subject).to_utf8_buffer():
        value = (value * 33 + int(byte)) % 10000
    return value

func simulate(config: Dictionary, subject: String, available: bool = true) -> Dictionary:
    var issues: Array = []
    if typeof(config.get("flags")) != TYPE_DICTIONARY:
        return _result({}, [_issue("error", "input_error", "flags", "Expected a flags object.", "Provide named flag definitions.")])
    var flags: Dictionary = config["flags"]
    var names: Array = flags.keys()
    names.sort()
    for name in names:
        var rule = flags[name]
        var path := "flags." + str(name)
        if typeof(rule) != TYPE_DICTIONARY or typeof(rule.get("default")) != TYPE_BOOL:
            issues.append(_issue("error", "invalid_flag", path, "Flag needs a boolean default.", "Specify default as true or false."))
            continue
        var rollout = rule.get("rollout", 0)
        if (typeof(rollout) != TYPE_INT and typeof(rollout) != TYPE_FLOAT) or not is_finite(float(rollout)) or float(rollout) < 0 or float(rollout) > 100:
            issues.append(_issue("error", "invalid_flag", path, "Rollout must be a number from 0 to 100.", "Set a valid rollout percentage."))
        if typeof(rule.get("requires", [])) != TYPE_ARRAY:
            issues.append(_issue("error", "invalid_flag", path, "Requires must be an array of flag names.", "List prerequisite flag names in an array."))
            continue
        for dependency in rule.get("requires", []):
            if typeof(dependency) != TYPE_STRING or not flags.has(dependency):
                issues.append(_issue("error", "unknown_prerequisite", path, "A prerequisite is not a defined flag name.", "Correct the prerequisite list."))
    if not issues.is_empty():
        return _result({}, issues)
    var states := {}
    var decisions := {}
    for name in names:
        if not states.has(name):
            _evaluate(str(name), flags, subject, available, states, decisions, issues)
    return _result({} if not issues.is_empty() else decisions, issues)

func _evaluate(name: String, flags: Dictionary, subject: String, available: bool, states: Dictionary, decisions: Dictionary, issues: Array) -> bool:
    if int(states.get(name, 0)) == 1:
        issues.append(_issue("error", "prerequisite_cycle", "flags." + name, "Flag prerequisites form a cycle.", "Break the prerequisite cycle."))
        return false
    if int(states.get(name, 0)) == 2:
        return bool(decisions[name]["enabled"])
    states[name] = 1
    var rule: Dictionary = flags[name]
    var prereqs_ok := true
    for dependency in rule.get("requires", []):
        if not _evaluate(str(dependency), flags, subject, available, states, decisions, issues):
            prereqs_ok = false
    var cohort := bucket(name, subject)
    var candidate := cohort < int(round(float(rule.get("rollout", 0)) * 100.0)) if available else bool(rule["default"])
    var enabled := candidate and prereqs_ok
    decisions[name] = {"enabled": enabled, "candidate": candidate, "prerequisites_met": prereqs_ok, "bucket": cohort, "source": "rollout" if available else "default"}
    states[name] = 2
    return enabled

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func _result(decisions: Dictionary, issues: Array) -> Dictionary:
    return {"summary": {"flags": decisions.size(), "issues": issues.size()}, "decisions": decisions, "issues": issues}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Feature Flag and Rollout Simulation", "", "Summary: " + str(result["summary"]), "", "## Decisions"]
    var names: Array = result["decisions"].keys()
    names.sort()
    for name in names:
        var decision: Dictionary = result["decisions"][name]
        lines.append("- `%s`: enabled=%s, source=%s, bucket=%s, prerequisites_met=%s" % [name, decision["enabled"], decision["source"], decision["bucket"], decision["prerequisites_met"]])
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
