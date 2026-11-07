extends Control
const Art = preload("res://scripts/horror_theme.gd")
const State = preload("res://scripts/objective_state.gd")
var state: Dictionary = {}
var text := ""
var _title: Label
var _hint: Label
var _chapter: Label
var _change_time := 0.0
var _segments: Array[ColorRect] = []
var _accent: ColorRect
var gameplay_visible := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(28,26)
	size = Vector2(448,124)
	var plate := Panel.new()
	plate.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel",Art.panel(Color(.025,.032,.031,.88),Color(.25,.29,.27,.35),0,1))
	add_child(plate)
	_accent = ColorRect.new()
	_accent.size = Vector2(3,124)
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_accent)
	_chapter = _label("GREYHAVEN / THE HOUSE",Vector2(20,12),12,Art.MUTED)
	_title = _label("",Vector2(40,31),26,Art.INK)
	_title.add_theme_font_override("font",Art.heading_font())
	_title.size = Vector2(390,34)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint = _label("",Vector2(20,69),15,Color("bec4b8"))
	_hint.size = Vector2(408,27)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(4):
		var segment := ColorRect.new()
		segment.position = Vector2(20+index*104,108)
		segment.size = Vector2(96,2)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(segment)
		_segments.append(segment)
	visible = false

func _label(value: String, at: Vector2, points: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func update_state(progression: Node, code_found: bool = false) -> void:
	var next := State.describe(progression,code_found)
	if next == state: return
	var changed := not state.is_empty()
	state = next
	text = state.title
	_title.text = text
	_hint.text = state.hint
	var accent := Color("cf927e") if state.urgent else Color("c9ad72")
	_accent.color = accent
	for index in range(4): _segments[index].color = Art.GREEN if index < state.step else accent if index == state.step else Color("3c4540")
	_change_time = 2.2 if changed else 0.0
	_chapter.text = "OBJECTIVE UPDATED" if changed else "GREYHAVEN / THE HOUSE"
	queue_redraw()

func _process(delta: float) -> void:
	visible = gameplay_visible and not get_tree().paused
	if _change_time > 0:
		_change_time = maxf(0,_change_time-delta)
		if _change_time == 0: _chapter.text = "GREYHAVEN / THE HOUSE"

func _draw() -> void:
	if state.is_empty(): return
	var c := Vector2(23,48)
	draw_polyline(PackedVector2Array([c+Vector2(0,-7),c+Vector2(7,0),c+Vector2(0,7),c+Vector2(-7,0),c+Vector2(0,-7)]),_accent.color,1.6,true)
