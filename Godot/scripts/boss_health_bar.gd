class_name BlackwebBossHealthBar
extends Control
const Art = preload("res://scripts/horror_theme.gd")
var title: Label
var phase: Label
var meter: ProgressBar
var trail: ProgressBar
var _lag := 100.0
var _linger := 0.0
var fighting := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Art.apply_theme(self)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	anchor_left = 0.21
	anchor_right = 0.79
	offset_top = 24
	offset_bottom = 100
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.add_theme_stylebox_override("panel", Art.steel_panel(12))
	add_child(plate)
	title = Label.new()
	title.text = "THE SMILING SPIDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 7
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("e5d7c7"))
	add_child(title)
	for is_trail in [true, false]:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		bar.offset_left = 18
		bar.offset_right = -18
		bar.offset_top = 36
		bar.offset_bottom = 43
		var background := StyleBoxFlat.new()
		background.bg_color = Color("281f20") if is_trail else Color.TRANSPARENT
		bar.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("c6a179") if is_trail else Color("a74440")
		bar.add_theme_stylebox_override("fill", fill)
		add_child(bar)
		if is_trail: trail = bar
		else: meter = bar
	phase = Label.new()
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	phase.offset_top = 49
	phase.add_theme_font_size_override("font_size", 12)
	phase.add_theme_color_override("font_color", Color("a6ada1"))
	add_child(phase)
	hide()

func begin(current: float, maximum: float) -> void:
	fighting = true
	_linger = 0.0
	meter.max_value = maxf(1.0, maximum)
	trail.max_value = meter.max_value
	meter.value = clampf(current, 0.0, meter.max_value)
	_lag = meter.value
	trail.value = _lag
	show()
	update_health(current, maximum)

func update_health(current: float, maximum: float) -> void:
	meter.max_value = maxf(1.0, maximum)
	trail.max_value = meter.max_value
	meter.value = clampf(current, 0.0, meter.max_value)
	phase.text = "THE HUNT" if meter.value > meter.max_value * 0.5 else "DESPERATION"

func finish() -> void:
	fighting = false
	_linger = 1.5
	phase.text = "ENCOUNTER COMPLETE"

func reset() -> void:
	fighting = false
	_linger = 0.0
	hide()

func _process(delta: float) -> void:
	if not visible: return
	_lag = move_toward(_lag, meter.value, delta * meter.max_value * 0.48)
	trail.value = _lag
	if not fighting:
		_linger -= delta
		if _linger <= 0.0: hide()
