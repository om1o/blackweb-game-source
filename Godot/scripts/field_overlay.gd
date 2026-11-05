class_name BlackwebFieldOverlay
extends Control
## Original, code-drawn readable and vault interfaces. Gameplay owns pause state.
signal closed
signal code_submitted(code: String)
signal armor_claimed(item: StringName)
var mode := ""
var digits := ""
var _content: VBoxContainer
var _display: Label
var _message: Label
var _card: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	hide()

func _base(title: String, subtitle: String, paper := false) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.003, 0.006, 0.008, 0.91)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(PRESET_CENTER)
	_card.offset_left = -430
	_card.offset_right = 430
	_card.offset_top = -322
	_card.offset_bottom = 322
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c7bda4") if paper else Color("10191b")
	style.border_color = Color("847553") if paper else Color("697264")
	style.set_border_width_all(1)
	style.set_content_margin_all(30)
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 15)
	_card.add_child(_content)
	_content.add_child(_label(subtitle, 13, Color("4b493e") if paper else Color("b7aa86")))
	_content.add_child(_label(title, 32, Color("242b29") if paper else Color("e2dfd3")))
	_content.add_child(HSeparator.new())
	show()
	# A short scale-in makes a picked-up paper settle into a readable close-up.
	_card.pivot_offset = Vector2(430, 322)
	_card.scale = Vector2(0.92, 0.92)
	_card.modulate.a = 0.0
	var motion := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	motion.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(_card, "modulate:a", 1.0, 0.16)

func show_paper(title: String, text: String) -> void:
	mode = "paper"
	_base(title.to_upper(), "GREYHAVEN  /  RECOVERED DOCUMENT", true)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 360
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_content.add_child(scroll)
	var body := _label(text, 25, Color("282d2a"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(body)
	_content.add_child(_label("Read at your own pace. The house is paused.", 14, Color("4b493e")))
	var close := _button("PUT DOWN PAPER       E / ESC", close_overlay)
	_content.add_child(close)
	close.grab_focus()

func show_vault(has_key: bool, known: bool) -> void:
	mode = "vault"
	digits = ""
	_base("PERSONNEL VAULT", "GREYHAVEN STORAGE  /  MANUAL OVERRIDE 08")
	_content.add_child(_label("KEY INSERTED" if has_key else "VAULT KEY REQUIRED", 16, Color("d4bf8b") if has_key else Color("c77b66")))
	_content.add_child(_label("Four digits. Mica left a note beside the plant.", 17, Color("a9b4ad")))
	_display = _label("_  _  _  _", 42, Color("e1dac0"))
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_display)
	_message = _label("Code note found in your records." if known else "Find the hidden paper beside the plant.", 15, Color("a9b4ad"))
	_content.add_child(_message)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "DEL", "0", "ENTER"]:
		var button := _button(key, press_digit.bind(key))
		button.custom_minimum_size = Vector2(180, 46)
		grid.add_child(button)
	_content.add_child(_button("STEP BACK       ESC", close_overlay))

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

func set_message(text: String) -> void:
	if is_instance_valid(_message): _message.text = text

func show_armor(claimed: Dictionary) -> void:
	mode = "armor"
	_base("LEATHER FIELD KIT", "VAULT CONTENTS  /  FOUR STARTER ARMOR PIECES")
	_content.add_child(_label("Take each piece, then equip it from inventory [I].\nArmor uses its own slots. Your three quick items stay available.", 20, Color("b8c0b8")))
	for entry in [[&"leather_shirt", "SHIRT", 6], [&"leather_pants", "PANTS", 5], [&"leather_hood", "HOOD", 4], [&"leather_shoes", "SHOES", 3]]:
		var id: StringName = entry[0]
		var taken := claimed.has(str(id))
		var button := _button("%s     /     %s" % [entry[1], "COLLECTED" if taken else "TAKE  ·  %d%% protection" % entry[2]], func(): armor_claimed.emit(id))
		button.disabled = taken
		_content.add_child(button)
	_message = _label("Full kit: 18% damage reduction. Maximum health remains 100.", 17, Color("d1bc8a"))
	_content.add_child(_message)
	_content.add_child(_button("CLOSE KIT       E / ESC", close_overlay))

func close_overlay() -> void:
	hide()
	mode = ""
	closed.emit()

func _label(text: String, pixels: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = MOUSE_FILTER_IGNORE
	return result

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 45
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("24302f")
	style.border_color = Color("626d60")
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("e4dfcf"))
	button.pressed.connect(callback)
	return button
