## Save Corruption and Recovery Tester - loader robustness.
## From one good JSON save it builds corrupted variants: truncated halfway,
## empty, not JSON, a JSON array or null root, each top-level key replaced by
## a value of another type, each key removed, an unexpected extra key, and
## all numbers set to large negative or huge values. Each variant is passed
## to the loader's static load_save(text). The result must be a Dictionary
## (unless --allow-null) that the loader's own static is_valid(save) accepts.
## Loader script errors show in the output and count as no fallback.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"loader": "", "allow_null": false}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var sample: Variant = _read_json(input)
    if typeof(sample) != TYPE_DICTIONARY:
        return _fail(input, "Sample save missing or not a JSON object.", "Pass --save=<good JSON save>.", "bad_input")
    var script: Variant = load(str(opts["loader"])) if ResourceLoader.exists(str(opts["loader"])) else null
    if not script is GDScript:
        return _fail(str(opts["loader"]), "Loader script not found.", "Pass --loader=<script with static load_save(text)>.", "bad_input")
    return evaluate(mutants(sample), script, opts)


## [{name, text}] corrupted variants of a sample save.
func mutants(sample: Dictionary) -> Array:
    var good := JSON.stringify(sample)
    var out: Array = [
        {"name": "truncated", "text": good.substr(0, good.length() / 2)},
        {"name": "empty", "text": ""},
        {"name": "not_json", "text": "SAVE v2 #!@ garbage"},
        {"name": "array_root", "text": "[1, 2, 3]"},
        {"name": "null_root", "text": "null"},
        {"name": "extra_key", "text": JSON.stringify(_with(sample, "__unexpected__", {"deep": [1, 2]}))}]
    for k in sample.keys():
        out.append({"name": "wrong_type:%s" % k, "text": JSON.stringify(_with(sample, k, _other(sample[k])))})
        var copy := sample.duplicate(true)
        copy.erase(k)
        out.append({"name": "missing:%s" % k, "text": JSON.stringify(copy)})
    out.append({"name": "negative_numbers", "text": JSON.stringify(_numbers(sample, -999999999))})
    out.append({"name": "huge_numbers", "text": JSON.stringify(_numbers(sample, 1e300))})
    return out


func _with(d: Dictionary, k: String, v: Variant) -> Dictionary:
    var c := d.duplicate(true)
    c[k] = v
    return c


func _other(v: Variant) -> Variant:
    match typeof(v):
        TYPE_INT, TYPE_FLOAT:
            return "not a number"
        TYPE_STRING:
            return 12345
        TYPE_ARRAY:
            return {"oops": true}
        TYPE_DICTIONARY:
            return [1, 2, 3]
        TYPE_BOOL:
            return "yes"
    return 0


func _numbers(v: Variant, value: float) -> Variant:
    match typeof(v):
        TYPE_INT, TYPE_FLOAT:
            return value
        TYPE_ARRAY:
            return v.map(func(x): return _numbers(x, value))
        TYPE_DICTIONARY:
            var out := {}
            for k in v.keys():
                out[k] = _numbers(v[k], value)
            return out
    return v


func evaluate(variants: Array, script: GDScript, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var has_valid := false
    for m in script.get_script_method_list():
        if str(m["name"]) == "is_valid":
            has_valid = true
    var safe := 0
    for v in variants:
        var got: Variant = script.call("load_save", v["text"])
        if got == null:
            if opts["allow_null"]:
                safe += 1
            else:
                issues.append(_issue("warning", "no_fallback", str(options.get("loader", "")), 0, "%s: loader returned null (or errored); the player would lose their save state." % v["name"], "Return a default save (and keep a backup of the damaged file) instead of null."))
        elif typeof(got) != TYPE_DICTIONARY:
            issues.append(_issue("error", "bad_return", str(options.get("loader", "")), 0, "%s: loader returned %s, not a Dictionary." % [v["name"], type_string(typeof(got))], "Check the parsed root type before returning it."))
        elif has_valid and not bool(script.call("is_valid", got)):
            issues.append(_issue("error", "accepted_invalid", str(options.get("loader", "")), 0, "%s: loader returned a save its own is_valid() rejects." % v["name"], "Validate each field and fall back to defaults for bad ones."))
        else:
            safe += 1
    return _finish({"variants": variants.size(), "handled": safe}, issues)


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
    var lines: Array = ["# Save Corruption and Recovery Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
