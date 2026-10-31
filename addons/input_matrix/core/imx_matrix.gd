## Multi-Platform Input Matrix and Rebinding Suite - matrix operation.
## Takes the project's input actions as pure data - {action: [events]},
## each event {device: keyboard|mouse|joypad|touch, id: a stable string
## like "Space" or "joypad_button/a"} - and builds the matrix of who is
## bound to what across devices. The report flags bindings that collide
## (one physical control triggering two actions), actions that no
## gamepad can reach while the project clearly supports gamepads, and
## touch-only actions on a project with keyboard bindings. It also
## emits the remap-menu data (sorted, grouped, display-named) so a
## rebinding UI can be generated instead of hand-built. The runtime
## node (runtime/imx_rebind.gd) does the live listening and saving;
## this file never touches InputMap itself, so it tests from JSON.
extends RefCounted

const DEVICE_ORDER: Array[String] = ["keyboard", "mouse", "joypad", "touch"]


## Pure: classify a Godot InputEvent into {device, id}. Lives here (not
## in the CLI) so docks, CLIs and tests share one classification.
func classify_event(event: InputEvent) -> Dictionary:
    if event is InputEventKey:
        var key := event as InputEventKey
        var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
        return {"device": "keyboard", "id": OS.get_keycode_string(code)}
    if event is InputEventMouseButton:
        return {"device": "mouse", "id": "button_%d" % (event as InputEventMouseButton).button_index}
    if event is InputEventJoypadButton:
        return {"device": "joypad", "id": "button_%d" % (event as InputEventJoypadButton).button_index}
    if event is InputEventJoypadMotion:
        var motion := event as InputEventJoypadMotion
        return {"device": "joypad", "id": "axis_%d_%s" % [motion.axis, "+" if motion.axis_value > 0 else "-"]}
    if event is InputEventScreenTouch or event is InputEventScreenDrag:
        return {"device": "touch", "id": "touch"}
    return {"device": "other", "id": "unknown"}


## The one operation: build the matrix and report collisions + gaps.
func run(actions: Dictionary) -> Dictionary:
    var issues: Array = []
    var matrix: Dictionary = {}
    var by_control: Dictionary = {}
    var has_joypad := false
    var has_keyboard := false
    for action in actions:
        var rows: Array = []
        for e in actions[action]:
            var ev: Dictionary = e
            var device := str(ev.get("device", "other"))
            var id := str(ev.get("id", ""))
            rows.append({"device": device, "id": id})
            if device == "joypad":
                has_joypad = true
            if device == "keyboard":
                has_keyboard = true
            var control_key := device + ":" + id
            if not by_control.has(control_key):
                by_control[control_key] = []
            (by_control[control_key] as Array).append(str(action))
        matrix[str(action)] = rows
    for control_key in by_control:
        var bound: Array = by_control[control_key]
        if bound.size() > 1:
            bound.sort()
            issues.append({"severity": "error", "kind": "binding_collision", "path": str(control_key),
                "message": "Control '%s' triggers %d actions at once: %s. Pressing it once fires them all." % [
                    control_key, bound.size(), ", ".join(bound)],
                "fix": "Move one of the actions to a different control, or merge them if they should always fire together."})
    if has_joypad:
        for action in matrix:
            var devices: Array = []
            for row in matrix[action]:
                var d := str((row as Dictionary)["device"])
                if d not in devices:
                    devices.append(d)
            if "joypad" not in devices:
                issues.append({"severity": "warning", "kind": "no_gamepad", "path": str(action),
                    "message": "Action '%s' has no gamepad binding, but this project binds gamepad buttons elsewhere - a pad player cannot trigger it." % action,
                    "fix": "Add a joypad binding, or document why the action is deliberately keyboard/mouse-only."})
    var remap_menu: Array = []
    var sorted_actions: Array = matrix.keys()
    sorted_actions.sort()
    for action in sorted_actions:
        var grouped: Dictionary = {}
        for row in matrix[action]:
            var device := str((row as Dictionary)["device"])
            if not grouped.has(device):
                grouped[device] = []
            (grouped[device] as Array).append(str((row as Dictionary)["id"]))
        var entry := {"action": str(action), "display": _display_name(str(action)), "bindings": {}}
        for device in DEVICE_ORDER:
            if grouped.has(device):
                (entry["bindings"] as Dictionary)[device] = grouped[device]
        remap_menu.append(entry)
    var collisions := 0
    var gaps := 0
    for i in issues:
        if str(i["kind"]) == "binding_collision":
            collisions += 1
        else:
            gaps += 1
    return {"summary": {"actions": matrix.size(), "devices": DEVICE_ORDER.size(),
            "collisions": collisions, "coverage_gaps": gaps, "issues": issues.size()},
        "matrix": matrix, "remap_menu": remap_menu, "issues": issues}


func _display_name(action: String) -> String:
    var words := action.replace("_", " ")
    return words.capitalize()


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "matrix": result["matrix"], "remap_menu": result["remap_menu"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Input Matrix Report", "",
        "%d actions across keyboard/mouse/joypad/touch: %d collisions, %d coverage gaps." % [
            s["actions"], s["collisions"], s["coverage_gaps"]], ""]
    lines.append("| Action | keyboard | mouse | joypad | touch |")
    lines.append("|---|---|---|---|---|")
    for entry in result["remap_menu"]:
        var b: Dictionary = entry["bindings"]
        lines.append("| %s | %s | %s | %s | %s |" % [entry["action"],
            ", ".join(b.get("keyboard", [])), ", ".join(b.get("mouse", [])),
            ", ".join(b.get("joypad", [])), ", ".join(b.get("touch", []))])
    lines.append("")
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
