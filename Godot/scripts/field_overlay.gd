class_name BlackwebFieldOverlay
extends Control
## Document inspection and vault interfaces. Gameplay owns pause state.
signal closed
signal code_submitted(code: String)
signal armor_claimed(item: StringName)
var mode := ""
var digits := ""
var _content: VBoxContainer
var _display: Label
var _message: Label
var _card: PanelContainer
const EvidenceScript = preload("res://scripts/tutorial_evidence.gd")
const UI = preload("res://scripts/horror_theme.gd")
const PAPER_MAX_ZOOM := 4.0
var _paper_viewport: Control
var _paper_image: TextureRect
var _paper_transcript: PanelContainer
var _paper_text_button: Button
var _paper_zoom_label: Label
var _paper_zoom := 1.0
var _paper_fit_scale := 1.0
var _paper_pan := Vector2.ZERO
var _paper_dragging := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	UI.apply_theme(self)
	resized.connect(_layout_card)
	hide()

func _base(title: String, subtitle: String) -> void:
	_clear_content()
	var dim := ColorRect.new()
	dim.color = Color(0.004, 0.007, 0.005, 0.94)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(PRESET_CENTER)
	_card.add_theme_stylebox_override("panel", UI.steel_panel(72))
	add_child(_card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	_content.add_child(_label(subtitle, 13, UI.MUTED))
	_content.add_child(_label(title, 34, UI.INK))
	var rule := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = UI.EDGE
	line.thickness = 1
	rule.add_theme_stylebox_override("separator", line)
	_content.add_child(rule)
	_layout_card()
	show()
	_card.modulate.a = 0.0
	var motion := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_property(_card, "modulate:a", 1.0, 0.16)

func _layout_card() -> void:
	if not is_instance_valid(_card): return
	var extent := Vector2(minf(760.0, size.x - 48.0), minf(680.0 if mode == "vault" else 720.0, size.y - 32.0))
	_card.offset_left = -extent.x * 0.5
	_card.offset_right = extent.x * 0.5
	_card.offset_top = -extent.y * 0.5
	_card.offset_bottom = extent.y * 0.5

func show_paper(title: String, text: String, texture: Texture2D = null) -> void:
	_clear_content()
	mode = "paper"
	if texture == null: texture = EvidenceScript.document_texture(title)
	var dim := ColorRect.new()
	dim.color = Color(0.004, 0.006, 0.008, 0.98)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var toolbar := HBoxContainer.new()
	toolbar.name = "PaperToolbar"
	toolbar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	toolbar.offset_left = 20
	toolbar.offset_right = -20
	toolbar.offset_top = 12
	toolbar.offset_bottom = 60
	toolbar.add_theme_constant_override("separation", 10)
	add_child(toolbar)
	var heading := _label(title.to_upper(), 26, UI.INK)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(heading)
	var minus := _button("−", func(): zoom_paper(_paper_zoom / 1.35))
	minus.custom_minimum_size.x = 44
	minus.disabled = texture == null
	toolbar.add_child(minus)
	_paper_zoom_label = _label("100%", 16, UI.GREEN)
	_paper_zoom_label.custom_minimum_size.x = 52
	_paper_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(_paper_zoom_label)
	var plus := _button("+", func(): zoom_paper(_paper_zoom * 1.35))
	plus.custom_minimum_size.x = 44
	plus.disabled = texture == null
	toolbar.add_child(plus)
	var fit := _button("FIT", reset_paper_view)
	fit.custom_minimum_size.x = 66
	fit.disabled = texture == null
	toolbar.add_child(fit)
	_paper_text_button = _button("READ TEXT", toggle_paper_transcript)
	_paper_text_button.custom_minimum_size.x = 132
	_paper_text_button.disabled = texture == null
	toolbar.add_child(_paper_text_button)
	var close := _button("CLOSE  [E / ESC]", close_overlay)
	close.custom_minimum_size.x = 174
	toolbar.add_child(close)
	_paper_viewport = Control.new()
	_paper_viewport.name = "PaperImageViewport"
	_paper_viewport.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_paper_viewport.offset_left = 20
	_paper_viewport.offset_right = -20
	_paper_viewport.offset_top = 78
	_paper_viewport.offset_bottom = -48
	_paper_viewport.clip_contents = true
	_paper_viewport.mouse_default_cursor_shape = CURSOR_DRAG
	_paper_viewport.gui_input.connect(_paper_gui_input)
	_paper_viewport.resized.connect(_layout_paper)
	add_child(_paper_viewport)
	_paper_image = TextureRect.new()
	_paper_image.name = "GeneratedPaperImage"
	_paper_image.texture = texture
	_paper_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper_image.stretch_mode = TextureRect.STRETCH_SCALE
	_paper_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_paper_image.mouse_filter = MOUSE_FILTER_IGNORE
	_paper_viewport.add_child(_paper_image)
	_paper_transcript = PanelContainer.new()
	_paper_transcript.name = "PaperTranscript"
	_paper_transcript.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_paper_transcript.offset_left = 50
	_paper_transcript.offset_right = -50
	_paper_transcript.offset_top = 78
	_paper_transcript.offset_bottom = -48
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d6cbb5")
	style.set_content_margin_all(28)
	_paper_transcript.add_theme_stylebox_override("panel", style)
	add_child(_paper_transcript)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_paper_transcript.add_child(scroll)
	var body := _label(text, 28, Color("282d2a"))
	body.add_theme_font_override("font", UI.body_font())
	body.name = "ExactDocumentTranscript"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(body)
	_paper_transcript.visible = texture == null
	_paper_viewport.visible = texture != null
	var help_text := "SCROLL / + −  ZOOM    ·    DRAG  PAN    ·    F  FIT    ·    T  READ TEXT    ·    HOUSE PAUSED" if texture != null else "SCROLL  READ    ·    E / ESC  PUT DOWN    ·    HOUSE PAUSED"
	var hint := _label(help_text, 14, Color("b8c0b8"))
	hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	hint.offset_top = -37
	hint.offset_bottom = -10
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	show()
	reset_paper_view()
	_layout_paper.call_deferred()
	close.grab_focus()

func _clear_content() -> void:
	_paper_dragging = false
	_card = null
	_content = null
	_display = null
	_message = null
	_paper_viewport = null
	_paper_image = null
	_paper_transcript = null
	_paper_text_button = null
	_paper_zoom_label = null
	for child in get_children():
		remove_child(child)
		child.queue_free()

func reset_paper_view() -> void:
	_paper_zoom = 1.0
	_paper_pan = Vector2.ZERO
	_paper_dragging = false
	_layout_paper()

func zoom_paper(value: float, anchor := Vector2(-1, -1)) -> void:
	if not is_instance_valid(_paper_image) or _paper_image.texture == null: return
	if anchor.x < 0.0: anchor = _paper_viewport.size * 0.5
	var old_zoom := _paper_zoom
	_paper_zoom = clampf(value, 1.0, PAPER_MAX_ZOOM)
	# Keep the point under the cursor stationary while magnifying the sheet.
	_paper_pan = anchor - _paper_viewport.size * 0.5 - (anchor - _paper_viewport.size * 0.5 - _paper_pan) * (_paper_zoom / old_zoom)
	_layout_paper()

func _layout_paper() -> void:
	if not is_instance_valid(_paper_viewport) or not is_instance_valid(_paper_image) or _paper_image.texture == null: return
	var available := _paper_viewport.size
	if available.x < 1.0 or available.y < 1.0: return
	var source := _paper_image.texture.get_size()
	_paper_fit_scale = minf(available.x / source.x, available.y / source.y)
	var image_size := source * _paper_fit_scale * _paper_zoom
	var limit := (image_size - available).max(Vector2.ZERO) * 0.5
	_paper_pan = _paper_pan.clamp(-limit, limit)
	_paper_image.size = image_size
	_paper_image.position = (available - image_size) * 0.5 + _paper_pan
	_paper_zoom_label.text = "%d%%" % roundi(_paper_zoom * 100.0)

func toggle_paper_transcript() -> void:
	if not is_instance_valid(_paper_transcript) or _paper_image.texture == null: return
	_paper_transcript.visible = not _paper_transcript.visible
	_paper_viewport.visible = not _paper_transcript.visible
	_paper_text_button.text = "VIEW PAPER" if _paper_transcript.visible else "READ TEXT"
	_paper_dragging = false

func _paper_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_paper(_paper_zoom * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), event.position)
			_paper_viewport.accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_paper_dragging = event.pressed
			if event.double_click: reset_paper_view()
			_paper_viewport.accept_event()
	elif event is InputEventMouseMotion and _paper_dragging:
		_paper_pan += event.relative
		_layout_paper()
		_paper_viewport.accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or mode != "paper" or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE, KEY_E: close_overlay()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: zoom_paper(_paper_zoom * 1.35)
		KEY_MINUS, KEY_KP_SUBTRACT: zoom_paper(_paper_zoom / 1.35)
		KEY_F, KEY_HOME: reset_paper_view()
		KEY_T: toggle_paper_transcript()
		_: return
	get_viewport().set_input_as_handled()

func show_vault(has_key: bool, known: bool) -> void:
	mode = "vault"
	digits = ""
	_base("PERSONNEL VAULT", "GREYHAVEN  /  STORAGE ACCESS  /  UNIT 08")
	_content.add_child(_label("●  KEY INSERTED" if has_key else "●  VAULT KEY REQUIRED", 16, UI.GREEN if has_key else UI.RED))
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UI.panel(Color("080e0a"), UI.EDGE, 10))
	_content.add_child(well)
	_display = _label("_  _  _  _", 48, UI.INK)
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	well.add_child(_display)
	_message = _label("CODE NOTE RECOVERED  ·  Enter four digits." if known else "Mica left the four-digit code beside the plant.", 16, UI.MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_message)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 7)
	_content.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "DEL", "0", "ENTER"]:
		var button := _button(key, press_digit.bind(key))
		button.custom_minimum_size = Vector2(144, 45)
		UI.button(button, 24 if key.is_valid_int() else 16, key == "ENTER")
		grid.add_child(button)
	_content.add_child(_button("STEP BACK                                  ESC", close_overlay))
	grid.get_child(0).grab_focus()

func press_digit(key: String) -> void:
	if mode != "vault": return
	if key == "DEL": digits = digits.left(maxi(0, digits.length() - 1))
	elif key == "ENTER":
		if digits.length() != 4: set_message("Enter all four digits.")
		else: code_submitted.emit(digits)
	elif digits.length() < 4 and key.is_valid_int() and key.length() == 1: digits += key
	if is_instance_valid(_display):
		var parts: Array[String] = []
		for i in range(4): parts.append(digits[i] if i < digits.length() else "_")
		_display.text = "  ".join(parts)

func handle_vault_key(event: InputEventKey) -> bool:
	if mode != "vault" or not visible or not event.pressed or event.echo: return false
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]: press_digit("ENTER")
	elif event.keycode in [KEY_BACKSPACE, KEY_DELETE]: press_digit("DEL")
	elif event.unicode >= 48 and event.unicode <= 57: press_digit(String.chr(event.unicode))
	else:
		# Some keyboard layouts/drivers report physical keypad keys without Unicode.
		var keypad := [KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]
		var digit := keypad.find(event.keycode)
		if digit < 0: return false
		press_digit(str(digit))
	return true

func set_message(text: String) -> void:
	if is_instance_valid(_message):
		_message.text = text
		_message.add_theme_color_override("font_color", UI.RED)

func show_armor(claimed: Dictionary) -> void:
	mode = "armor"
	_base("LEATHER FIELD KIT", "PERSONNEL VAULT  /  RECOVERED EQUIPMENT")
	var instructions := _label("Collect the pieces. Equip them from inventory [I].", 19, UI.MUTED)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(instructions)
	for entry in [[&"leather_shirt", "SHIRT", 6, "Torso"], [&"leather_pants", "PANTS", 5, "Legs"], [&"leather_hood", "HOOD", 4, "Head"], [&"leather_shoes", "SHOES", 3, "Feet"]]:
		var id: StringName = entry[0]
		var taken := claimed.has(str(id))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.panel(UI.PANEL, UI.EDGE, 12))
		_content.add_child(row)
		var layout := HBoxContainer.new()
		layout.add_theme_constant_override("separation", 20)
		row.add_child(layout)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = SIZE_EXPAND_FILL
		detail.add_theme_constant_override("separation", 3)
		layout.add_child(detail)
		detail.add_child(_label("LEATHER " + entry[1], 24, UI.INK))
		detail.add_child(_label("%s  ·  %d%% damage reduction" % [entry[3], entry[2]], 16, UI.MUTED))
		var button := _button("COLLECTED" if taken else "TAKE", func(): armor_claimed.emit(id))
		button.custom_minimum_size.x = 144
		button.size_flags_vertical = SIZE_SHRINK_CENTER
		button.set_meta("armor_item", id)
		button.disabled = taken
		layout.add_child(button)
	_message = _label("FULL KIT  ·  18% damage reduction  /  100 maximum health\nArmor slots are separate from your three quick items.", 16, UI.GREEN)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_message)
	var close := _button("CLOSE KIT                                  E / ESC", close_overlay)
	_content.add_child(close)
	close.grab_focus()

func close_overlay() -> void:
	if not visible: return
	_paper_dragging = false
	hide()
	mode = ""
	closed.emit()

func _label(text: String, pixels: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", color)
	if pixels >= 24:
		result.add_theme_font_override("font", UI.heading_font())
	result.mouse_filter = MOUSE_FILTER_IGNORE
	return result

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 45
	UI.button(button, 17)
	button.pressed.connect(callback)
	return button
