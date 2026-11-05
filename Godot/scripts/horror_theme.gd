class_name BlackwebHorrorTheme
extends RefCounted
## Shared original interface palette and bundled Barlow typography.
const BACKGROUND := Color("101713")
const PANEL := Color("19221c")
const INK := Color("dcdccf")
const MUTED := Color("8f9a90")
const GREEN := Color("a3b29c")
const RED := Color("ad7067")
const EDGE := Color("435147")
static var _body: FontFile
static var _medium: FontFile
static var _heading: FontFile
const STEEL_TEXTURE := "res://assets/generated/interface_steel_panel_v1.png"
static var _steel: Texture2D

static func body_font() -> FontFile:
	if _body == null: _body = _font("Barlow-Regular.ttf")
	return _body

static func medium_font() -> FontFile:
	if _medium == null: _medium = _font("Barlow-Medium.ttf")
	return _medium

static func heading_font() -> FontFile:
	if _heading == null: _heading = _font("BarlowCondensed-SemiBold.ttf")
	return _heading

static func _font(file: String) -> FontFile:
	var font := FontFile.new()
	font.data = FileAccess.get_file_as_bytes("res://assets/fonts/barlow/" + file)
	return font

static func apply_theme(root: Control) -> void:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = 17
	for kind in ["Label", "Button", "CheckButton", "OptionButton"]:
		theme.set_color("font_color", kind, INK)
	theme.set_font("normal_font", "RichTextLabel", body_font())
	theme.set_font("bold_font", "RichTextLabel", medium_font())
	theme.set_font("italics_font", "RichTextLabel", body_font())
	theme.set_font("bold_italics_font", "RichTextLabel", medium_font())
	theme.set_stylebox("panel", "PopupMenu", panel(BACKGROUND, EDGE, 10))
	theme.set_stylebox("hover", "PopupMenu", panel(PANEL, GREEN, 6))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("focus", "CheckButton", panel(Color.TRANSPARENT, GREEN, 4))
	root.theme = theme

static func heading(label: Label, size: int = 30) -> void:
	label.add_theme_font_override("font", heading_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)

static func panel(fill: Color = PANEL, edge: Color = EDGE, inset: int = 18, border: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_content_margin_all(inset)
	return box

static func steel_panel(inset: int = 26) -> StyleBox:
	if _steel == null:
		if ResourceLoader.exists(STEEL_TEXTURE):
			_steel = load(STEEL_TEXTURE) as Texture2D
		elif FileAccess.file_exists(STEEL_TEXTURE):
			# Source runs can inspect newly generated artwork before editor import.
			var image := Image.load_from_file(STEEL_TEXTURE)
			if image != null and not image.is_empty(): _steel = ImageTexture.create_from_image(image)
	if _steel == null: return panel(BACKGROUND, EDGE, inset)
	var box := StyleBoxTexture.new()
	box.texture = _steel
	box.modulate_color = Color(0.84, 0.86, 0.84, 1.0)
	# Preserve the rim and screws while only the quiet center stretches.
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: box.set_texture_margin(side, 72.0)
	box.set_content_margin_all(inset)
	return box

static func button(control: Button, size: int = 17, primary: bool = false) -> void:
	control.add_theme_font_override("font", medium_font())
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_focus_color", Color("f0f0e5"))
	control.add_theme_color_override("font_hover_color", Color("f0f0e5"))
	control.add_theme_color_override("font_disabled_color", Color("59645a"))
	var normal := panel(Color("29372b") if primary else Color("19231c"), Color("7f927c") if primary else Color("4c5d4e"), 10)
	normal.shadow_color = Color(0, 0, 0, 0.70)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 2)
	normal.border_blend = true
	var hover := panel(Color("304033"), GREEN, 10)
	hover.shadow_color = Color(0, 0, 0, 0.65)
	hover.shadow_size = 3
	hover.shadow_offset = Vector2(0, 2)
	hover.border_blend = true
	var focus := panel(Color.TRANSPARENT, GREEN, 10)
	focus.border_width_left = 2
	var pressed := panel(Color("101910"), Color("687b65"), 10)
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 8
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("focus", focus)
	control.add_theme_stylebox_override("pressed", pressed)
	control.add_theme_stylebox_override("disabled", panel(Color(.035, .045, .038, .4), Color(.20, .26, .21, .45), 10))
