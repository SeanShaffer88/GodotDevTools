## Dialogue and Quest Debugger - editor dock.
@tool
extends VBoxContainer

const Graph := preload("res://addons/dialogue_quest/core/dqd_graph.gd")
const LayoutOp := preload("res://addons/dialogue_quest/core/dqd_layout.gd")

var _results: RichTextLabel
var _dialogue_picker: OptionButton
var _graph_view: GraphView
var _graph_op = null
var _issues: Array = []


func _init() -> void:
    name = "Dialogue and Quest Debugger"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Dialogue and Quest Debugger"
    title.tooltip_text = "Show dialogue branches and quest dependencies as a graph, simulate choices, and inspect which conditions activate."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Dialogue and Quest Debugger check on this project, list the results below, and fill the graph view."
    run_btn.pressed.connect(_on_run)
    add_child(run_btn)
    var help_btn := Button.new()
    help_btn.text = "?"
    help_btn.tooltip_text = "Show plain-words help for this tool."
    help_btn.pressed.connect(func() -> void: _results.text = HELP_TEXT)
    add_child(help_btn)
    _dialogue_picker = OptionButton.new()
    _dialogue_picker.tooltip_text = "Which dialogue the graph below draws. Run check first to fill this list."
    _dialogue_picker.item_selected.connect(func(_idx: int) -> void: _redraw_graph())
    add_child(_dialogue_picker)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(320, 340)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.tooltip_text = "The drawn branch graph: boxes are dialogue nodes (green outline = start, blue = marked ending, orange = flagged problem, red dashed = missing target), arrows are choices. [if] means the choice has a condition."
    _graph_view = GraphView.new()
    scroll.add_child(_graph_view)
    add_child(scroll)
    _results = RichTextLabel.new()
    _results.fit_content = true
    _results.custom_minimum_size = Vector2(320, 300)
    _results.tooltip_text = "Results of the last run. Run the check to fill this in."
    add_child(_results)
    _results.text = "Press Run check."


const HELP_TEXT := "Dialogue/quest JSON files anywhere in the project are found automatically. Run lists branches pointing at missing nodes, unreachable writing, unmarked dead ends and quest dependency problems, and draws the selected dialogue's branch graph: pick a dialogue above the graph, boxes are nodes and arrows are choices ([if] = conditional). Orange boxes carry a warning from the report, red dashed boxes are targets that do not exist. The core's simulate(dialogue, picks, state) plays a conversation: it evaluates each choice's condition against the state you give it and applies effects, so you can see exactly which branches open."


func _on_run() -> void:
    var result: Dictionary = _run_check()
    var lines: Array[String] = []
    var s: Dictionary = result.get("summary", {})
    lines.append("Summary: " + str(s))
    var issues: Array = result.get("issues", [])
    if issues.is_empty():
        lines.append("No problems found.")
    for i in issues:
        lines.append("[%s] %s" % [i.get("severity", "info"), i.get("message", "")])
        if i.get("fix", "") != "":
            lines.append("  Fix: " + str(i["fix"]))
    var results_list: Array = result.get("results", [])
    for r in results_list:
        lines.append("%s - %s" % [r.get("path", ""), "; ".join(r.get("reasons", []))])
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Graph.new()
    var found: Dictionary = {"errors": []}
    var files := op.find_files()
    found = op.load_files(files)
    var result := op.analyse()
    result["issues"] = found["errors"] + result["issues"]
    _graph_op = op
    _issues = result["issues"]
    _fill_picker()
    return result


func _fill_picker() -> void:
    _dialogue_picker.clear()
    if _graph_op == null:
        return
    var ids: Array = _graph_op.dialogues.keys()
    ids.sort()
    for did in ids:
        _dialogue_picker.add_item(str(did))
    if _dialogue_picker.item_count > 0:
        _dialogue_picker.select(0)
        _redraw_graph()
    else:
        _graph_view.layout = {}
        _graph_view.queue_redraw()


func _redraw_graph() -> void:
    if _graph_op == null or _dialogue_picker.item_count == 0:
        return
    var did := _dialogue_picker.get_item_text(_dialogue_picker.selected)
    var lay = LayoutOp.new()
    var graph: Dictionary = lay.layout_dialogue(_graph_op, did, _issues)
    _graph_view.layout = graph
    _graph_view.custom_minimum_size = graph.get("content_size", Vector2(320, 340))
    _graph_view.queue_redraw()


## The drawn node-graph pane. Pure painting of a dqd_layout result -
## no checking and no layout maths live here.
class GraphView:
    extends Control

    var layout: Dictionary = {}

    const COLOR_EDGE := Color(0.55, 0.6, 0.7)
    const COLOR_BROKEN := Color(0.9, 0.3, 0.3)
    const COLOR_NODE := Color(0.18, 0.19, 0.23)
    const COLOR_START := Color(0.35, 0.7, 0.4)
    const COLOR_END := Color(0.4, 0.55, 0.85)
    const COLOR_WARN := Color(0.9, 0.65, 0.25)
    const COLOR_GHOST := Color(0.9, 0.3, 0.3)
    const COLOR_TEXT := Color(0.92, 0.92, 0.95)
    const COLOR_SUBTEXT := Color(0.65, 0.66, 0.72)

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        for e in layout.get("edges", []):
            var pts: Array = e.get("points", [])
            if pts.size() != 2:
                continue
            var p0: Vector2 = pts[0]
            var p1: Vector2 = pts[1]
            var broken := bool(e.get("broken", false))
            var col: Color = COLOR_BROKEN if broken else COLOR_EDGE
            draw_line(p0, p1, col, 2.0)
            var dir: Vector2 = (p1 - p0).normalized()
            if dir != Vector2.ZERO:
                var side := Vector2(-dir.y, dir.x)
                var arrow := PackedVector2Array([p1, p1 - dir * 9.0 + side * 4.5,
                    p1 - dir * 9.0 - side * 4.5])
                draw_colored_polygon(arrow, col)
            var label := str(e.get("choice_text", ""))
            if bool(e.get("has_condition", false)):
                label += " [if]"
            var mid: Vector2 = (p0 + p1) * 0.5
            draw_string(font, mid + Vector2(4, -5), label,
                HORIZONTAL_ALIGNMENT_LEFT, 170, 11, COLOR_SUBTEXT)
        for n in layout.get("nodes", []):
            var rect: Rect2 = n.get("rect", Rect2())
            var flags: Array = n.get("flags", [])
            var ghost := bool(n.get("ghost", false))
            if ghost:
                _draw_dashed_rect(rect, COLOR_GHOST)
            else:
                draw_rect(rect, COLOR_NODE)
                var outline := COLOR_START if bool(n.get("start", false)) else COLOR_END
                if not flags.is_empty():
                    outline = COLOR_WARN
                draw_rect(rect, outline, false, 2.0)
            draw_string(font, rect.position + Vector2(8, 18), str(n.get("id", "")),
                HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x) - 16, 13, COLOR_TEXT)
            var sub := str(n.get("speaker", ""))
            if sub == "":
                sub = "(missing target)" if ghost else str(n.get("text", ""))
            draw_string(font, rect.position + Vector2(8, 38), sub,
                HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x) - 16, 11, COLOR_SUBTEXT)

    func _draw_dashed_rect(rect: Rect2, col: Color) -> void:
        var step := 8.0
        for edge in 4:
            var a := Vector2.ZERO
            var b := Vector2.ZERO
            if edge == 0:
                a = rect.position
                b = rect.position + Vector2(rect.size.x, 0)
            elif edge == 1:
                a = rect.position + Vector2(rect.size.x, 0)
                b = rect.end
            elif edge == 2:
                a = rect.end
                b = rect.position + Vector2(0, rect.size.y)
            else:
                a = rect.position + Vector2(0, rect.size.y)
                b = rect.position
            var length := a.distance_to(b)
            var dir := Vector2.ZERO
            if length > 0.0:
                dir = (b - a) / length
            var pos := 0.0
            var on := true
            while pos < length:
                var seg := minf(step, length - pos)
                if on:
                    draw_line(a + dir * pos, a + dir * (pos + seg), col, 2.0)
                pos += seg
                on = not on
