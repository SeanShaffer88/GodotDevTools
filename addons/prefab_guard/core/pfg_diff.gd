## Smart Prefab and Variant Instance Manager - diff operation.
## Reads a scene's text and the text of every prefab it instantiates,
## then classifies each instance override honestly: an override whose
## value now equals the prefab's own default is dead weight
## (default_drift - it survived a prefab edit that made it redundant and
## will now silently resist the next one), and an override that differs
## hides that property from all future prefab edits (drifted_property -
## intentional for placement, dangerous for values the prefab author
## expects to control). The rollback plan is generated as data - one op
## per dead override - and nothing is ever written to a scene unless the
## CLI is run with an explicit --apply, because scene files are source
## code and this project treats them that way.
extends RefCounted

## Parse [ext_resource ... id="X"] -> {id: path} for PackedScenes.
func parse_ext_scenes(text: String) -> Dictionary:
    var out: Dictionary = {}
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[ext_resource ") and "type=\"PackedScene\"" in line:
            var id := _attr(line, "id")
            var path := _attr(line, "path")
            if id != "" and path != "":
                out[id] = path
    return out


## Parse node blocks: [{name, instance_id, parent, props: {k: v_text}}].
func parse_nodes(text: String) -> Array:
    var nodes: Array = []
    var current: Dictionary = {}
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[node "):
            if not current.is_empty():
                nodes.append(current)
            current = {"name": _attr(line, "name"), "parent": _attr(line, "parent"),
                "instance_id": _instance_id(line), "props": {}}
        elif line.begins_with("["):
            if not current.is_empty():
                nodes.append(current)
            current = {}
        elif not current.is_empty() and line != "" and "=" in line and not line.begins_with(";"):
            var eq := line.find(" = ")
            if eq > 0:
                (current["props"] as Dictionary)[line.substr(0, eq)] = line.substr(eq + 3)
    if not current.is_empty():
        nodes.append(current)
    return nodes


func _instance_id(line: String) -> String:
    var i := line.find("instance=ExtResource(\"")
    if i < 0:
        return ""
    var rest := line.substr(i + 22)
    return rest.substr(0, rest.find("\""))


func _attr(line: String, key: String) -> String:
    var marker := key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var rest := line.substr(i + marker.length())
    return rest.substr(0, rest.find("\""))


## Prefab defaults = the root node's properties (first parentless node).
func prefab_defaults(prefab_text: String) -> Dictionary:
    for n in parse_nodes(prefab_text):
        var node: Dictionary = n
        if str(node["parent"]) == "":
            return node["props"]
    return {}


## The one operation: diff every prefab instance in scene_text against
## its prefab's defaults. prefab_texts: {res path: text}.
func analyze(scene_text: String, scene_path: String, prefab_texts: Dictionary) -> Dictionary:
    var issues: Array = []
    var plan: Array = []
    var ext_scenes := parse_ext_scenes(scene_text)
    var instances := 0
    var overrides := 0
    for n in parse_nodes(scene_text):
        var node: Dictionary = n
        var iid := str(node["instance_id"])
        if iid == "" or not ext_scenes.has(iid):
            continue
        instances += 1
        var prefab_path := str(ext_scenes[iid])
        if not prefab_texts.has(prefab_path):
            issues.append({"severity": "warning", "kind": "prefab_missing", "path": prefab_path,
                "message": "Instance '%s' points at %s, whose text was not provided - its overrides cannot be classified." % [node["name"], prefab_path],
                "fix": "Make sure the prefab file exists and is readable."})
            continue
        var defaults := prefab_defaults(str(prefab_texts[prefab_path]))
        for prop in node["props"]:
            var p := str(prop)
            if p == "name":
                continue
            overrides += 1
            var value := str((node["props"] as Dictionary)[p])
            if defaults.has(p):
                var default_value := str(defaults[p])
                if _normalize(value) == _normalize(default_value):
                    issues.append({"severity": "info", "kind": "default_drift", "path": scene_path,
                        "message": "Instance '%s' overrides %s = %s, which is exactly the prefab's current default - a dead override." % [
                            node["name"], p, value],
                        "fix": "Remove the override so future prefab edits reach this instance; the rollback plan does exactly that."})
                    plan.append({"scene": scene_path, "node": str(node["name"]), "prop": p,
                        "op": "remove_override", "value": value})
                else:
                    issues.append({"severity": "warning", "kind": "drifted_property", "path": scene_path,
                        "message": "Instance '%s' overrides %s (prefab says %s) - prefab edits to this property will never reach this instance." % [
                            node["name"], p, default_value],
                        "fix": "Keep it if the difference is the point (placement); if the prefab should own this value, remove the override."})
            else:
                plan.append({"scene": scene_path, "node": str(node["name"]), "prop": p,
                    "op": "keep", "value": value})
    var dead := 0
    var hiding := 0
    for i in issues:
        match str(i["kind"]):
            "default_drift":
                dead += 1
            "drifted_property":
                hiding += 1
    return {"summary": {"instances": instances, "overrides": overrides,
            "dead_overrides": dead, "hiding_overrides": hiding, "issues": issues.size()},
        "plan": plan, "issues": issues}


func _normalize(value: String) -> String:
    return value.replace(" ", "").replace(".0)", ")").to_lower()


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "plan": result.get("plan", [])}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Prefab Instance Report", "",
        "%d instance(s), %d override(s): %d dead, %d hiding the prefab. %d findings." % [
            s["instances"], s["overrides"], s["dead_overrides"], s["hiding_overrides"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    lines.append("")
    lines.append("## Rollback plan (applied only with --apply)")
    for op in result.get("plan", []):
        lines.append("- %s: %s.%s" % [op["op"], op["node"], op["prop"]])
    return "\n".join(lines) + "\n"
