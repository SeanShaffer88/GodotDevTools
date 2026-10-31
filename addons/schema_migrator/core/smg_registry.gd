## Schema and Save-Game Migrator - registry operation.
## Save files and custom-resource data carry a schema_version. The
## registry JSON lists every version's required fields and the migration
## steps between versions, each step a list of small ops: rename,
## default, delete, move. This operation walks a save from its version
## to the newest along the registered path, validates the result against
## the target field list, and reports anything it could not migrate.
## The registry is re-read on every run - that is the whole hot-reload
## story: change the schema file, run again, and the new rules apply
## without restarting anything. Pure Dictionary work, no engine state.
extends RefCounted

## Registry shape:
## {"name": "player", "current_version": 3,
##  "fields": {"3": ["health", "position", "inventory"]},
##  "migrations": [{"from": 1, "to": 2, "ops": [
##      {"op": "rename", "from": "hp", "to": "health"},
##      {"op": "default", "field": "stamina", "value": 100},
##      {"op": "delete", "field": "legacy_flag"},
##      {"op": "move", "from": "pos", "to": "position"}]}]}
var registry: Dictionary = {}


func load_registry(path: String) -> Dictionary:
    registry = {}
    if not FileAccess.file_exists(path):
        return {"errors": [{"severity": "error", "kind": "missing_file", "path": path,
            "message": "Schema registry not found: %s" % path,
            "fix": "Pass an existing registry JSON, or check the path for a typo."}]}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return {"errors": [{"severity": "error", "kind": "bad_json", "path": path,
            "message": "%s is not valid registry JSON." % path,
            "fix": "Fix the JSON syntax; nothing can migrate until it parses."}]}
    registry = parsed
    return {"errors": []}


## Find the migration path from one version to another: an array of
## migration dicts, or empty when no registered path exists.
func migration_path(from_version: int, to_version: int) -> Array:
    var path: Array = []
    var current := from_version
    var guard := 0
    while current != to_version and guard < 64:
        guard += 1
        var step: Dictionary = {}
        for m in registry.get("migrations", []):
            if int(m.get("from", -1)) == current:
                step = m
                break
        if step.is_empty():
            return []
        path.append(step)
        current = int(step.get("to", current))
    return path if current == to_version else []


func apply_ops(data: Dictionary, ops: Array) -> Dictionary:
    var out := data.duplicate(true)
    for op in ops:
        match str(op.get("op", "")):
            "rename":
                if out.has(str(op.get("from", ""))):
                    out[str(op.get("to", ""))] = out[str(op.get("from", ""))]
                    out.erase(str(op.get("from", "")))
            "move":
                if out.has(str(op.get("from", ""))):
                    out[str(op.get("to", ""))] = out[str(op.get("from", ""))]
                    out.erase(str(op.get("from", "")))
            "default":
                if not out.has(str(op.get("field", ""))):
                    out[str(op.get("field", ""))] = op.get("value", null)
            "delete":
                out.erase(str(op.get("field", "")))
    return out


## The one operation: migrate one save dict (carrying schema_version) to
## the registry's current_version and validate it. Returns the migrated
## data plus the standard report shape.
func migrate(save: Dictionary, to_version: int = -1) -> Dictionary:
    var issues: Array = []
    var target := to_version if to_version >= 0 else int(registry.get("current_version", 0))
    var from := int(save.get("schema_version", 0))
    var migrated := save.duplicate(true)
    var applied: Array = []
    if registry.is_empty():
        issues.append({"severity": "error", "kind": "no_registry", "path": "",
            "message": "No schema registry loaded; nothing can be migrated.",
            "fix": "Load a registry JSON first (load_registry)."})
        return {"summary": {"from": from, "to": target, "applied": 0, "issues": 1},
            "data": save, "applied_steps": [], "issues": issues}
    if from == target:
        applied = []
    else:
        var path := migration_path(from, target)
        if path.is_empty():
            issues.append({"severity": "error", "kind": "unmigratable", "path": "",
                "message": "No registered migration path from schema version %d to %d." % [from, target],
                "fix": "Add migration steps bridging the gap to the registry, or fix the save's schema_version if it is wrong."})
        else:
            for step in path:
                migrated = apply_ops(migrated, step.get("ops", []))
                migrated["schema_version"] = int(step.get("to", from))
                applied.append({"from": int(step.get("from", 0)), "to": int(step.get("to", 0)),
                    "ops": (step.get("ops", []) as Array).size()})
    var required: Array = []
    for key in registry.get("fields", {}):
        if int(str(key).to_int() if str(key).is_valid_int() else key) == target:
            required = registry["fields"][key]
    for field in required:
        if not migrated.has(str(field)):
            issues.append({"severity": "error", "kind": "missing_field", "path": str(field),
                "message": "After migration to version %d, required field '%s' is missing." % [target, field],
                "fix": "Add a default op for this field to the last migration step, or repair the save by hand."})
    return {"summary": {"from": from, "to": target, "applied": applied.size(),
            "issues": issues.size()},
        "data": migrated, "applied_steps": applied, "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "applied_steps": result.get("applied_steps", []), "data": result.get("data", {})}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Schema Migration Report", "",
        "Save moved from schema version %d to %d in %d step(s). %d problems." % [
            s["from"], s["to"], s["applied"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
