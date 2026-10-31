extends SceneTree
const Validator := preload("res://addons/telemetry_schema/core/tel_validator.gd")
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
    var validator = Validator.new()
    var fixture: Dictionary = validator.run("res://demo/telemetry/schema.json", "res://demo/telemetry/events.json")
    check("fixture loads", fixture["summary"]["events"] == 1)
    check("type mismatch detected", kinds(fixture).has("type_mismatch"))
    check("sensitive field detected", kinds(fixture).has("sensitive_field"))
    check("sample values omitted from JSON", not validator.to_json(fixture).contains("synthetic-example"))
    var schema := {"events": {"start": {"fields": {"level": {"type": "string", "required": true}, "n": {"type": "integer"}}}}}
    var clean: Dictionary = validator.analyze(schema, {"events": [{"name": "start", "fields": {"level": "a", "n": 3.0}}]})
    check("valid event and JSON integer pass", clean["issues"].is_empty())
    check("missing field flagged", kinds(validator.analyze(schema, {"events": [{"name": "start", "fields": {}}]})).has("missing_field"))
    check("unknown field flagged", kinds(validator.analyze(schema, {"events": [{"name": "start", "fields": {"extra": 1}}]})).has("unknown_field"))
    check("unknown event flagged", kinds(validator.analyze(schema, {"events": [{"name": "wrong", "fields": {}}]})).has("unknown_event"))
    check("boolean is not a number", not validator._matches(true, "number"))
    check("object, array, boolean and number accepted", validator._matches({}, "object") and validator._matches([], "array") and validator._matches(true, "boolean") and validator._matches(1.5, "number"))
    check("null is not a string", not validator._matches(null, "string"))
    check("malformed schema flags rejected", kinds(validator.analyze({"events": {"bad": {"fields": {"x": {"type": "string", "required": "yes"}}}}}, {"events": []})).has("schema_error"))
    check("fractional integer rejected", kinds(validator.analyze(schema, {"events": [{"name": "start", "fields": {"level": "a", "n": 2.5}}]})).has("type_mismatch"))
    check("invalid event shape flagged", kinds(validator.analyze(schema, {"events": [null]})).has("invalid_event"))
    check("invalid schema flagged", kinds(validator.analyze({"events": {"bad": {"fields": {"x": {"type": "decimal"}}}}}, {"events": []})).has("schema_error"))
    check("invalid samples flagged", kinds(validator.analyze(schema, {})).has("input_error"))
    check("missing file flagged", kinds(validator.run("res://missing_telemetry_schema.json", "res://demo/telemetry/events.json")).has("input_error"))
    check("markdown renders finding", validator.to_markdown(fixture).contains("sensitive_field"))
    check("JSON report parses", JSON.parse_string(validator.to_json(fixture)).has("issues"))
    print("Telemetry Schema TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
