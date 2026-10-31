## Local telemetry sample validation; payload values are never included in findings.
extends RefCounted
const TYPES := ["string", "number", "integer", "boolean", "object", "array"]

func run(schema_path: String, samples_path: String) -> Dictionary:
    var schema_result := _read_object(schema_path)
    var sample_result := _read_object(samples_path)
    var errors: Array = []
    if not schema_result["ok"]:
        errors.append(_issue("error", "input_error", schema_path, "Cannot read a JSON object from schema file.", "Provide a readable schema JSON object."))
    if not sample_result["ok"]:
        errors.append(_issue("error", "input_error", samples_path, "Cannot read a JSON object from samples file.", "Provide a readable sample JSON object."))
    if not errors.is_empty():
        return _result(0, errors)
    return analyze(schema_result["data"], sample_result["data"])

func _read_object(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return {"ok": false}
    return {"ok": true, "data": parser.data}

func analyze(schema: Dictionary, samples: Dictionary) -> Dictionary:
    var issues: Array = []
    if typeof(schema.get("events")) != TYPE_DICTIONARY:
        return _result(0, [_issue("error", "schema_error", "schema.events", "Expected an event-definition object.", "Define event names under events.")])
    var definitions: Dictionary = schema["events"]
    for event_name in definitions:
        var event_def = definitions[event_name]
        if typeof(event_def) != TYPE_DICTIONARY or typeof(event_def.get("fields")) != TYPE_DICTIONARY:
            issues.append(_issue("error", "schema_error", "schema.events." + str(event_name), "Event definition needs a fields object.", "Define each field and its type."))
            continue
        for field_name in event_def["fields"]:
            var rule = event_def["fields"][field_name]
            if typeof(rule) != TYPE_DICTIONARY or str(rule.get("type", "")) not in TYPES or (rule.has("required") and typeof(rule["required"]) != TYPE_BOOL) or (rule.has("sensitive") and typeof(rule["sensitive"]) != TYPE_BOOL):
                issues.append(_issue("error", "schema_error", "schema.events.%s.fields.%s" % [event_name, field_name], "Invalid field rule.", "Use a supported type and boolean required/sensitive flags."))
    if not issues.is_empty():
        return _result(0, issues)
    if typeof(samples.get("events")) != TYPE_ARRAY:
        return _result(0, [_issue("error", "input_error", "samples.events", "Expected an events array.", "Provide an array of sample events.")])
    var events: Array = samples["events"]
    for index in range(events.size()):
        var path := "events[%d]" % index
        var event = events[index]
        if typeof(event) != TYPE_DICTIONARY or typeof(event.get("name")) != TYPE_STRING or typeof(event.get("fields")) != TYPE_DICTIONARY:
            issues.append(_issue("error", "invalid_event", path, "Event needs a string name and fields object.", "Correct the sample event shape."))
            continue
        var name: String = event["name"]
        if not definitions.has(name):
            issues.append(_issue("warning", "unknown_event", path, "Event name is not in the schema.", "Define the event or remove it from the sample."))
            continue
        var fields: Dictionary = event["fields"]
        var rules: Dictionary = definitions[name]["fields"]
        for field_name in rules:
            var rule: Dictionary = rules[field_name]
            if bool(rule.get("required", false)) and not fields.has(field_name):
                issues.append(_issue("warning", "missing_field", path + "." + str(field_name), "Required field is absent.", "Supply the field or change the schema."))
        for field_name in fields:
            var field_path := path + "." + str(field_name)
            if not rules.has(field_name):
                issues.append(_issue("warning", "unknown_field", field_path, "Field is not defined for this event.", "Define the field or remove it."))
                continue
            var rule: Dictionary = rules[field_name]
            if not _matches(fields[field_name], str(rule["type"])):
                issues.append(_issue("warning", "type_mismatch", field_path, "Field does not match schema type '%s'." % rule["type"], "Correct the field type."))
            if bool(rule.get("sensitive", false)):
                issues.append(_issue("warning", "sensitive_field", field_path, "Field is marked sensitive in the schema.", "Review collection and remove or protect the field before sending."))
    return _result(events.size(), issues)

func _matches(value, expected: String) -> bool:
    var kind := typeof(value)
    match expected:
        "string": return kind == TYPE_STRING
        "number": return kind == TYPE_INT or kind == TYPE_FLOAT
        "integer": return kind == TYPE_INT or (kind == TYPE_FLOAT and is_finite(value) and floor(value) == value)
        "boolean": return kind == TYPE_BOOL
        "object": return kind == TYPE_DICTIONARY
        "array": return kind == TYPE_ARRAY
    return false

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func _result(count: int, issues: Array) -> Dictionary:
    return {"summary": {"events": count, "issues": issues.size()}, "issues": issues}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Telemetry Schema Validation", "", "Summary: " + str(result["summary"]), "", "## Findings"]
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
