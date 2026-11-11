## Optional runtime helper. Call after layout has settled; it does not write
## anything unless save_snapshot() is explicitly called by the game.
extends RefCounted


## Capture enabled, visible BaseButtons and Controls in group "touch_target".
## Only the main Window's viewport is sampled. `metrics` can override `screen`
## and `window_offset_px` for synthetic tests or manually measured devices.
func capture(scene_root: Node, metrics: Dictionary = {}) -> Dictionary:
    if scene_root == null or not scene_root.is_inside_tree():
        return {}
    var screen_position := Vector2(DisplayServer.screen_get_position())
    var screen_size := DisplayServer.screen_get_size()
    var safe := DisplayServer.get_display_safe_area()
    var screen := {
        "size_px": [screen_size.x, screen_size.y],
        "safe_area_px": [safe.position.x - screen_position.x, safe.position.y - screen_position.y, safe.size.x, safe.size.y],
        "density_dpi": DisplayServer.screen_get_dpi(),
    }
    if metrics.has("screen"):
        if typeof(metrics["screen"]) != TYPE_DICTIONARY:
            return {}
        screen = metrics["screen"]
    var window_offset := Vector2(DisplayServer.window_get_position()) - screen_position
    if metrics.has("window_offset_px"):
        var offset: Variant = metrics["window_offset_px"]
        if typeof(offset) != TYPE_ARRAY or offset.size() != 2 or typeof(offset[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(offset[1]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(offset[0])) or not is_finite(float(offset[1])):
            return {}
        window_offset = Vector2(float(offset[0]), float(offset[1]))
    var targets: Array = []
    var skipped := {"other_viewport": 0}
    _walk(scene_root, scene_root.get_tree().root, window_offset, targets, skipped)
    return {"version": 1, "screen": screen, "targets": targets, "capture": {"skipped_other_viewport": skipped["other_viewport"]}}


func _walk(node: Node, main_window: Window, offset: Vector2, targets: Array, skipped: Dictionary) -> void:
    if node is Control:
        var control: Control = node
        var candidate := control is BaseButton or control.is_in_group("touch_target")
        var enabled := not (control is BaseButton) or not (control as BaseButton).disabled
        if candidate and enabled and control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
            if control.get_viewport() != main_window:
                skipped["other_viewport"] += 1
            else:
                var transform := control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas()
                transform.origin += offset
                var box := _bounds(transform, control.size)
                var axis_aligned := (is_zero_approx(transform.x.y) and is_zero_approx(transform.y.x)) or (is_zero_approx(transform.x.x) and is_zero_approx(transform.y.y))
                targets.append({"path": str(control.get_path()), "rect_px": [box.position.x, box.position.y, box.size.x, box.size.y], "axis_aligned": axis_aligned})
    for child in node.get_children():
        _walk(child, main_window, offset, targets, skipped)


## Four transformed corners avoid get_global_rect's rotation/scale limitations.
func _bounds(transform: Transform2D, size: Vector2) -> Rect2:
    var corners := [transform * Vector2.ZERO, transform * Vector2(size.x, 0.0), transform * size, transform * Vector2(0.0, size.y)]
    var low: Vector2 = corners[0]
    var high: Vector2 = corners[0]
    for corner in corners:
        low = Vector2(minf(low.x, corner.x), minf(low.y, corner.y))
        high = Vector2(maxf(high.x, corner.x), maxf(high.y, corner.y))
    return Rect2(low, high - low)


func save_snapshot(snapshot: Dictionary, path: String) -> Error:
    if snapshot.is_empty() or path.is_empty():
        return ERR_INVALID_PARAMETER
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(snapshot, "  "))
    var err := file.get_error()
    file.close()
    return err
