class_name BlackwebHorrorMenu
extends Control

signal resume_requested
signal restart_requested
signal quit_requested
signal voice_test_requested
signal boss_test_requested
signal hud_layout_selected(index: int)
const Settings = preload("res://scripts/menu_settings.gd")
const MenuAudio = preload("res://scripts/menu_audio.gd")
const Art = preload("res://scripts/horror_theme.gd")
const BACKGROUND := "res://assets/generated/blackweb_menu_corridor_v1.png"
const INK := Color("dcdccf")
const MUTED := Color("8f9a90")
const GREEN := Color("a3b29c")
const RED := Color("ad7067")
var qa_mode := false
var settings = Settings.new()
var heading: Label
var menu_state: Label
var resume_button: Button
var restart_button: Button
var hud_picker: OptionButton
var options_button: Button
var extras_button: Button
var quit_button: Button
var master_slider: HSlider
var dialogue_slider: HSlider
var device_picker: OptionButton
var graphics_picker: OptionButton
var audio_message: Label
var fullscreen_toggle: CheckButton
var motion_toggle: CheckButton
var current_page := "main"
var _mode := "main"
var _can_continue := false
var _loaded := true
var _has_progress := false
var _audio: AudioStreamPlayer
var _image: TextureRect
var _image_shader: ShaderMaterial
var _navigation: VBoxContainer
var _title_block: VBoxContainer
var _panel: PanelContainer
var _pages: Dictionary = {}
var _main_notes: VBoxContainer
var _detail_title: Label
var _detail_copy: Label
var _status: Label
var _footer: Label
var _settings_state: Label
var _time := 0.0
var _animation: Tween
var _hidden_hud: Array[Dictionary] = []
var _suspended_viewport: Viewport
var _prior_disable_3d := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Art.apply_theme(self)
	if not qa_mode: settings.load_preferences()
	settings.configure_graphics(OS.get_cmdline_user_args())
	settings.apply(not qa_mode)
	settings.apply_graphics(get_viewport())
	_build()
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	_layout()
	present("main", false, true, false)
	_visibility_changed()

func _build() -> void:
	_audio = MenuAudio.new()
	_audio.name = "OriginalMenuTicks"
	add_child(_audio)
	var base := ColorRect.new()
	base.color = Color(.012, .018, .016, .80)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background_texture: Texture2D
	if ResourceLoader.exists(BACKGROUND) and FileAccess.file_exists(BACKGROUND + ".import"):
		background_texture = load(BACKGROUND) as Texture2D
	elif FileAccess.file_exists(BACKGROUND):
		var image := Image.new()
		if image.load(BACKGROUND) == OK: background_texture = ImageTexture.create_from_image(image)
	if background_texture != null:
		_image = TextureRect.new()
		_image.texture = background_texture
		_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_image)
		_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform vec2 drift=vec2(0.0); void fragment(){vec2 uv=(UV-vec2(0.5))/1.035+vec2(0.5)+drift;vec4 p=texture(TEXTURE,uv);float v=1.0-smoothstep(0.3,0.78,length(UV-vec2(0.5)))*0.40;COLOR=vec4(p.rgb*vec3(0.70,0.75,0.69)*v,1.0);}"
		_image_shader = ShaderMaterial.new()
		_image_shader.shader = shader
		_image.material = _image_shader
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil_shader := Shader.new()
	veil_shader.code = "shader_type canvas_item; void fragment(){float a=mix(0.91,0.09,smoothstep(0.24,0.78,UV.x));a=max(a,smoothstep(0.67,1.0,UV.y)*0.60);COLOR=vec4(0.014,0.020,0.017,a);}"
	var veil_material := ShaderMaterial.new()
	veil_material.shader = veil_shader
	veil.material = veil_material
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_block = VBoxContainer.new()
	_title_block.add_theme_constant_override("separation", 8)
	add_child(_title_block)
	_title_block.add_child(_label("A R A C H N O P H O B I A", 13, MUTED))
	heading = _label("BLACKWEB", 86, INK)
	Art.heading(heading, 86)
	_title_block.add_child(heading)
	menu_state = _label("CHAPTER 01  /  THE HOUSE", 13, GREEN)
	_title_block.add_child(menu_state)
	_navigation = VBoxContainer.new()
	_navigation.add_theme_constant_override("separation", 4)
	add_child(_navigation)
	restart_button = _nav_button("Start game", _request_new_game)
	resume_button = _nav_button("Continue", func():
		if _mode == "complete": boss_test_requested.emit()
		else: resume_requested.emit())
	options_button = _nav_button("Options", func(): show_page("options"))
	extras_button = _nav_button("Extras", func(): show_page("extras"))
	quit_button = _nav_button("Quit", func(): quit_requested.emit())
	_status = _label("No saved game", 14, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_main_notes = VBoxContainer.new()
	_main_notes.add_theme_constant_override("separation", 12)
	add_child(_main_notes)
	_main_notes.add_child(_label("GREYHAVEN  /  23:41", 12, GREEN))
	_detail_title = _label("You know this house.", 27, INK)
	_main_notes.add_child(_detail_title)
	_detail_copy = _label("The rooms feel different tonight.\nA phone rings somewhere inside.", 17, Color("aeb5a9"))
	_detail_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_notes.add_child(_detail_copy)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Art.steel_panel(24))
	add_child(_panel)
	_build_options()
	_build_extras()
	_build_new_game_confirmation()
	_panel.minimum_size_changed.connect(_layout)
	_footer = _label("↑ ↓  Navigate     Enter  Select     Esc  Back", 13, MUTED)
	add_child(_footer)
	var edition := _label("House / Nov 05 UI & interaction pass", 12, Color("8f9a90"))
	edition.name = "Edition"
	edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(edition)

func _page(name: String, title: String, description: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = name.capitalize() + "Page"
	page.add_theme_constant_override("separation", 16)
	_panel.add_child(page)
	_pages[name] = page
	var page_title := _label(title.to_upper(), 34, INK)
	Art.heading(page_title, 34)
	var heading_margin := MarginContainer.new()
	heading_margin.add_theme_constant_override("margin_left", 48)
	heading_margin.add_theme_constant_override("margin_right", 48)
	page.add_child(heading_margin)
	heading_margin.add_child(page_title)
	var copy := _label(description, 15, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(copy)
	page.add_child(_rule())
	return page

func _build_options() -> void:
	var page := _page("options", "Options", "Sound, display and accessibility. Changes apply immediately.")
	page.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 180
	scroll.follow_focus = true
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var graphics_row := HBoxContainer.new()
	content.add_child(graphics_row)
	var graphics_label := _label("Graphics", 17, INK)
	graphics_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_row.add_child(graphics_label)
	graphics_picker = OptionButton.new()
	graphics_picker.custom_minimum_size = Vector2(215, 38)
	graphics_picker.add_item("Quality · smooth edges")
	graphics_picker.add_item("Performance · full detail")
	graphics_picker.select(1 if settings.active_graphics_preset() == "performance" else 0)
	graphics_picker.disabled = not settings.graphics_override.is_empty()
	Art.button(graphics_picker, 14)
	graphics_picker.item_selected.connect(func(index: int): settings.graphics_preset = "quality" if index == 0 else "performance"; _apply_settings())
	graphics_row.add_child(graphics_picker)
	var graphics_note := _label("Set by the launch option for this session." if graphics_picker.disabled else "Both keep full resolution. Quality smooths edges; Performance skips that extra effect.", 12, MUTED)
	graphics_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(graphics_note)
	master_slider = _volume_row(content, "Master volume", settings.master_volume, func(value: float): settings.master_volume = value; _apply_settings())
	dialogue_slider = _volume_row(content, "Dialogue volume", settings.dialogue_volume, func(value: float): settings.dialogue_volume = value; _apply_settings())
	var device_row := VBoxContainer.new()
	device_row.add_theme_constant_override("separation", 4)
	content.add_child(device_row)
	device_row.add_child(_label("Sound output", 15, INK))
	device_picker = OptionButton.new()
	device_picker.custom_minimum_size.y = 36
	device_picker.fit_to_longest_item = false
	device_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Art.button(device_picker, 14)
	_refresh_devices()
	device_picker.item_selected.connect(func(index: int): settings.output_device = str(device_picker.get_item_metadata(index)); _apply_settings(); audio_message.text = "Output changed. Use Test voice to check it.")
	device_row.add_child(device_picker)
	fullscreen_toggle = _toggle_row(content, "Fullscreen", settings.fullscreen, func(value: bool): settings.fullscreen = value; _apply_settings(true))
	motion_toggle = _toggle_row(content, "Reduced motion", settings.reduced_motion, func(value: bool): settings.reduced_motion = value; _apply_settings())
	var motion_note := _label("Stops background drift and the arrival camera movement.", 12, MUTED)
	motion_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(motion_note)
	var hud_row := HBoxContainer.new()
	content.add_child(hud_row)
	var hud_label := _label("HUD style", 17, INK)
	hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_row.add_child(hud_label)
	hud_picker = OptionButton.new()
	hud_picker.custom_minimum_size = Vector2(215, 38)
	for label in ["Field", "Survival", "Minimal", "Vertical"]: hud_picker.add_item(label)
	hud_picker.select(settings.hud_layout)
	_style_button(hud_picker, 15)
	hud_picker.item_selected.connect(func(index: int): settings.hud_layout = index; _apply_settings(); hud_layout_selected.emit(index))
	hud_row.add_child(hud_picker)
	audio_message = _label("Choose your speakers or headphones, then test Luke's voice.", 13, MUTED)
	audio_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(audio_message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	page.add_child(row)
	row.add_child(_small_button("Test voice", func(): voice_test_requested.emit()))
	row.add_child(_small_button("Back", back))
	_settings_state = _label("Saved on this PC. No system volume changes.", 12, MUTED)
	page.add_child(_settings_state)

func _refresh_devices() -> void:
	if not is_instance_valid(device_picker): return
	device_picker.clear()
	for device in AudioServer.get_output_device_list():
		device_picker.add_item("System default" if device == "Default" else device)
		device_picker.set_item_metadata(device_picker.item_count - 1, device)
		if device == settings.output_device: device_picker.select(device_picker.item_count - 1)

func report_voice_test(status: Dictionary, started: bool) -> void:
	if not bool(status.get("voice_test_loaded", false)):
		audio_message.text = "Luke's voice file is missing. Reinstall the complete game folder."
	elif str(status.get("driver", "Dummy")) == "Dummy":
		audio_message.text = "The game could not connect to a sound device. Connect your speakers or headphones, then restart the game."
	elif settings.master_volume <= 0.0 or settings.dialogue_volume <= 0.0:
		audio_message.text = "Voice is muted here. Raise Master and Dialogue volume, then test again."
	elif started:
		audio_message.text = "Luke is speaking through %s. If silent, choose another output above and check the Windows volume mixer." % ("your system default" if AudioServer.output_device == "Default" else AudioServer.output_device)
	else:
		audio_message.text = "Voice could not start. Choose a sound output above, then try again."

func _build_extras() -> void:
	var page := _page("extras", "Extras", "A few things to remember before the lights go out.")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	page.add_child(tabs)
	var body := RichTextLabel.new()
	body.name = "ExtrasText"
	body.bbcode_enabled = true
	body.custom_minimum_size = Vector2(0, 310)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_font_size_override("bold_font_size", 17)
	body.add_theme_color_override("default_color", INK)
	body.scroll_active = true
	body.focus_mode = Control.FOCUS_ALL
	page.add_child(body)
	var content := {
		"Controls": "[b]Move & explore[/b]\nW A S D  ·  Move       Mouse  ·  Look\nShift  ·  Sprint       C  ·  Crouch\nSpace  ·  Jump       E  ·  Interact\n\n[b]Stay alive[/b]\n1 / 2 / 3  ·  Choose an equipped item\nLeft click  ·  Use / swing\nF  ·  Flashlight       I  ·  Inventory\nM  ·  Expand / close the house map\n\nEquip up to three items from your 50-space inventory. Supplies are used after their action finishes.\n\nEsc  ·  Pause / back       F1–F4  ·  HUD styles",
		"Story": "[b]Luke / Greyhaven maintenance worker[/b]\n\nHome after the late shift. Mica asked you to wait here, but her phone call breaks apart.\n\nKeep your flashlight alive. Search the familiar rooms. Find what she left behind.\n\n[b]Chapter 01 — The house[/b]\nFive rooms. One exit. The house keeps its own records.",
		"Credits": "[b]BLACKWEB[/b]\nOriginal game code, interaction systems, modeled supplies and effects created for this project.\n\n[b]Art & sound[/b]\nHouse, recovered audio and adult spider: supplied Arachnophobia resources, used with the owner's stated permission.\nLuke: Microsoft Rocketbox — MIT.\nArmor garments: Mindfront and Elvaerwyn — CC BY 4.0; Donitz — CC0. Fitted and adapted to leather for Blackweb.\nBrown leather: Rob Tuytel / Poly Haven — CC0.\nSelected props: Poly Haven — CC0.\nJuvenile spider: Literock Studios — packaged game license.\nDialogue: Kokoro stock synthetic voices.\nMenu background: original generated artwork.\nTypography: Barlow by Jeremy Tribby / Barlow Project — SIL Open Font License 1.1.\n\nFull source records and included license notices are retained with the project and distribution."
	}
	for label in ["Controls", "Story", "Credits"]:
		var text: String = content[label]
		tabs.add_child(_small_button(label, func(): body.text = text; body.scroll_to_line(0)))
	body.text = content.Controls
	page.add_child(_small_button("The garden / Smiling Spider", func(): boss_test_requested.emit()))
	page.add_child(_small_button("Back", back))

func _build_new_game_confirmation() -> void:
	var page := _page("new_game", "Start a new game?", "Your current tutorial progress will be replaced when the new game is saved.")
	page.add_child(_label("Return to the house with your three starter items.", 17, MUTED))
	page.add_child(_small_button("Start new game", func(): restart_requested.emit()))
	page.add_child(_small_button("Keep current game", back))

func _volume_row(parent: VBoxContainer, title: String, value: float, callback: Callable) -> HSlider:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	parent.add_child(stack)
	var row := HBoxContainer.new()
	stack.add_child(row)
	var label := _label(title, 17, INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var number := _label("%d%%" % roundi(value * 100), 15, GREEN)
	row.add_child(number)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value * 100
	slider.custom_minimum_size.y = 24
	var rail := _box(Color("39453b"), Color.TRANSPARENT, 0, 0)
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	var fill := _box(GREEN, Color.TRANSPARENT, 0, 0)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.value_changed.connect(func(amount: float): number.text = "%d%%" % roundi(amount); callback.call(amount / 100.0))
	stack.add_child(slider)
	return slider

func _toggle_row(parent: VBoxContainer, title: String, value: bool, callback: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = title
	button.button_pressed = value
	button.custom_minimum_size.y = 35
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.toggled.connect(callback)
	parent.add_child(button)
	return button

func _nav_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(350, 48)
	_style_button(button, 22)
	button.pressed.connect(func(): _audio.tick(true); callback.call())
	button.mouse_entered.connect(func(): if not button.disabled: button.grab_focus())
	button.focus_entered.connect(func(): _audio.tick())
	_navigation.add_child(button)
	return button

func _small_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(122, 38)
	_style_button(button, 15)
	button.pressed.connect(func(): _audio.tick(true); callback.call())
	return button

func _style_button(button: Button, font_size: int) -> void:
	Art.button(button, font_size)
	if font_size == 22:
		button.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 12))
		button.add_theme_stylebox_override("disabled", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 12))

func _box(fill: Color, edge: Color, border: int, inset: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.content_margin_left = inset
	box.content_margin_right = inset
	box.content_margin_top = inset
	box.content_margin_bottom = inset
	return box

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(.36, .44, .37, .45)
	rule.custom_minimum_size.y = 1
	return rule

func present(mode: String, can_continue: bool, loaded: bool = true, has_progress: bool = false) -> void:
	_mode = mode
	_can_continue = can_continue
	_loaded = loaded
	_has_progress = has_progress
	heading.text = "BLACKWEB"
	menu_state.text = "PAUSED  /  THE HOUSE" if mode == "pause" else ("CHAPTER COMPLETE  /  GREYHAVEN AWAITS" if mode == "complete" else "CHAPTER 01  /  THE HOUSE")
	resume_button.text = "Enter the garden" if mode == "complete" else ("Resume" if mode == "pause" else "Continue")
	resume_button.disabled = not loaded or (mode not in ["pause","complete"] and not can_continue)
	restart_button.text = "New game" if has_progress else "Start game"
	restart_button.disabled = not loaded
	_navigation.move_child(resume_button if mode in ["pause","complete"] else restart_button, 0)
	_status.text = "Progress saves automatically." if can_continue or mode == "pause" else "No saved game to continue."
	if mode == "complete": _status.text = "House checkpoint saved. The garden encounter is ready."
	if not loaded: _status.text = "The house could not be loaded."
	_detail_title.text = "A moment to breathe." if mode == "pause" else ("You found the way out." if mode == "complete" else "You know this house.")
	_detail_copy.text = "The house will wait.\nTake stock before you return." if mode == "pause" else ("The research annex is beyond the garden.\nSomething is waiting at its gate." if mode == "complete" else "The rooms feel different tonight.\nA phone rings somewhere inside.")
	show_page("main")
	show()
	_focus_main.call_deferred()

func show_page(page: String) -> void:
	current_page = page
	if page == "options": _refresh_devices()
	_panel.visible = page != "main"
	_main_notes.visible = page == "main"
	for key in _pages: _pages[key].visible = key == page
	_layout.call_deferred()
	_status.visible = page == "main"
	if page == "main":
		_focus_main.call_deferred()
	else:
		var controls: Array = _pages[page].find_children("*", "Control", true, false)
		for control in controls:
			if control.focus_mode == Control.FOCUS_ALL and control.visible:
				control.grab_focus.call_deferred()
				break
	if not settings.reduced_motion:
		if _animation != null and _animation.is_valid(): _animation.kill()
		_panel.modulate.a = .0 if page != "main" else 1.0
		_animation = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_animation.tween_property(_panel, "modulate:a", 1.0, .16)
	else: _panel.modulate.a = 1.0

func back() -> void:
	if current_page != "main": show_page("main")
	elif _mode == "pause": resume_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()

func _request_new_game() -> void:
	if _has_progress or _mode == "pause": show_page("new_game")
	else: restart_requested.emit()

func _focus_main() -> void:
	if not visible or current_page != "main": return
	if not resume_button.disabled and (_mode in ["pause","complete"] or _can_continue): resume_button.grab_focus()
	elif not restart_button.disabled: restart_button.grab_focus()
	else: options_button.grab_focus()

func _apply_settings(window_changes: bool = false) -> void:
	settings.apply(window_changes and not qa_mode)
	settings.apply_graphics(get_viewport())
	if _image_shader != null and settings.reduced_motion: _image_shader.set_shader_parameter("drift", Vector2.ZERO)
	if settings.reduced_motion and _animation != null and _animation.is_valid():
		_animation.kill()
		_panel.modulate.a = 1.0
	if not qa_mode: settings.save_preferences()
	if is_instance_valid(_settings_state): _settings_state.text = "Changes saved on this PC." if settings.last_save_ok else "Could not save preferences. Changes still apply for this session."

func _visibility_changed() -> void:
	if not is_node_ready(): return
	if visible:
		_suspend_world_rendering()
		_hidden_hud.clear()
		for sibling in get_parent().get_children():
			if sibling != self and sibling is CanvasItem:
				_hidden_hud.append({"node": sibling, "visible": sibling.visible})
				sibling.visible = false
	else:
		_restore_world_rendering()
		_restore_hud()
		_audio.stop()

func _suspend_world_rendering() -> void:
	if is_instance_valid(_suspended_viewport): return
	_suspended_viewport = get_viewport()
	_prior_disable_3d = _suspended_viewport.disable_3d
	_suspended_viewport.disable_3d = true

func _restore_world_rendering() -> void:
	if not is_instance_valid(_suspended_viewport): return
	_suspended_viewport.disable_3d = _prior_disable_3d
	_suspended_viewport = null

func _restore_hud() -> void:
	for entry in _hidden_hud:
		if is_instance_valid(entry.node): entry.node.visible = bool(entry.visible)
	_hidden_hud.clear()

func _layout() -> void:
	if not is_instance_valid(_title_block): return
	var left := maxf(42, size.x * .067)
	_title_block.position = Vector2(left, size.y * .105)
	_title_block.size.x = 460
	_navigation.position = Vector2(left - 12, size.y * .352)
	_navigation.size.x = 370
	_status.position = Vector2(left, size.y * .72)
	_status.size = Vector2(380, 60)
	_panel.position = Vector2(size.x * .48, size.y * .12)
	_panel.size = Vector2(size.x * .45, size.y * .76)
	_main_notes.position = Vector2(size.x * .66, size.y * .72)
	_main_notes.size.x = size.x * .28
	_footer.position = Vector2(left, size.y - 48)
	get_node("Edition").position = Vector2(size.x * .64, size.y - 47)
	get_node("Edition").size.x = size.x * .29

func _process(delta: float) -> void:
	if not visible or settings.reduced_motion or _image_shader == null: return
	_time += minf(delta, .1)
	_image_shader.set_shader_parameter("drift", Vector2(sin(_time * .055) * .004, cos(_time * .045) * .002))

func _exit_tree() -> void:
	_restore_world_rendering()
	_restore_hud()
