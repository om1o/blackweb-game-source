extends SceneTree
## Isolated native UI fixture: no house, player assets or existing save access.
const Menu = preload("res://scripts/horror_menu.gd")
const Settings = preload("res://scripts/menu_settings.gd")
const Hud = preload("res://scripts/status_hud.gd")
const Inventory = preload("res://scripts/inventory_grid.gd")
const Preview = preload("res://scripts/item_preview.gd")
const PlayerFactory = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []
var resumed := 0
var restarted := 0
var voices := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	results.append({"passed": value, "label": label})
	if not value: failures += 1; push_error(label)
func snap(name: String) -> void:
	for frame in range(4): await process_frame
	await create_timer(.2).timeout
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../Evidence/menu-%s.png" % name)
	check(root.get_texture().get_image().save_png(path) == OK, "Captured " + name)
func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var old_hud := Label.new()
	old_hud.text = "Gameplay HUD must not overlap the menu"
	host.add_child(old_hud)
	var hidden := Control.new()
	hidden.hide()
	host.add_child(hidden)
	var menu := Menu.new()
	menu.qa_mode = true
	host.add_child(menu)
	menu.resume_requested.connect(func(): resumed += 1)
	menu.restart_requested.connect(func(): restarted += 1)
	menu.voice_test_requested.connect(func(): voices += 1)
	await process_frame
	check(menu.resume_button.disabled and not menu.restart_button.disabled, "Fresh game has Start and unavailable Continue")
	check(not old_hud.visible and not hidden.visible, "Menu hides underlying HUD without revealing hidden overlays")
	await snap("main")
	menu._request_new_game()
	check(restarted == 1, "Fresh Start emits one game start")
	menu.present("main", true, true, true)
	check(not menu.resume_button.disabled and menu.restart_button.text == "New game", "Valid progress offers Continue and New game")
	menu._request_new_game()
	check(menu.current_page == "new_game" and restarted == 1, "Replacing progress opens confirmation first")
	menu.back()
	check(menu.current_page == "main" and resumed == 0, "Back returns from confirmation without starting play")
	menu.present("pause", true, true, false)
	check(menu.resume_button.text == "Resume" and not menu.resume_button.disabled, "Unsaved active run keeps Resume")
	menu.back()
	check(resumed == 1, "Escape/back from pause resumes once")
	menu.present("complete", false, true, true)
	check(menu.resume_button.disabled, "Completed chapter cannot Continue")
	menu.present("main", true, true, true)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = root.get_screen_transform() * menu.options_button.get_global_rect().get_center()
	click.global_position = click.position
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	click.button_mask = 0
	Input.parse_input_event(click)
	await process_frame
	check(menu.current_page == "options", "Real mouse click opens Options")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(menu.current_page == "main", "Real Escape returns from Options")
	menu.options_button.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	enter = enter.duplicate()
	enter.pressed = false
	Input.parse_input_event(enter)
	await process_frame
	check(menu.current_page == "options", "Keyboard focus and Enter open Options")
	menu.master_slider.value = 65
	menu.dialogue_slider.value = 75
	check(is_equal_approx(menu.settings.master_volume, .65) and is_equal_approx(menu.settings.dialogue_volume, .75), "Sliders change real master and dialogue gains")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")), linear_to_db(.65)), "Master gain reaches the actual bus")
	check(menu.device_picker.item_count > 0, "Output selector lists available game outputs")
	menu.report_voice_test({"voice_test_loaded": true, "driver": "WASAPI"}, true)
	check(menu.audio_message.text.contains("Luke is speaking"), "Voice test reports playback route in plain language")
	menu.report_voice_test({"voice_test_loaded": false}, false)
	check(menu.audio_message.text.contains("voice file is missing"), "Missing voice gives an actionable repair message")
	menu.report_voice_test({"voice_test_loaded": true, "driver": "Dummy"}, true)
	check(menu.audio_message.text.contains("could not connect"), "No audio driver gives a plain device message")
	menu.report_voice_test({"voice_test_loaded": true, "driver": "WASAPI"}, true)
	await snap("options")
	check(menu.graphics_picker.is_visible_in_tree() and menu.graphics_picker.get_global_rect().end.y < root.get_visible_rect().size.y, "Graphics selector is visible inside the Options scrolling area")
	check(menu._panel.get_global_rect().end.y <= root.get_visible_rect().size.y - 25, "Options panel and its persistent buttons fit the screen")
	check(menu._settings_state.get_global_rect().end.y < root.get_visible_rect().size.y - 25, "Options saved-status footer remains on screen")
	menu.motion_toggle.button_pressed = true
	check(menu.settings.reduced_motion, "Reduced motion applies immediately")
	menu.show_page("extras")
	await snap("extras")
	var preferences := Settings.new()
	preferences.path = "user://menu_fixture_preferences.cfg"
	preferences.master_volume = .4
	preferences.dialogue_volume = .8
	preferences.reduced_motion = true
	preferences.fullscreen = true
	preferences.output_device = "Unavailable QA output"
	preferences.hud_layout = 2
	check(preferences.save_preferences(), "Preferences write in isolated test directory")
	var restored := Settings.new()
	restored.path = preferences.path
	restored.load_preferences()
	check(restored.master_volume == .4 and restored.dialogue_volume == .8 and restored.reduced_motion and restored.fullscreen and restored.output_device == preferences.output_device, "Audio display and accessibility preferences survive reload")
	restored.apply(false)
	check(AudioServer.output_device == "Default", "Unavailable saved output falls back to system default")
	menu.hide()
	check(old_hud.visible and not hidden.visible, "Leaving menu restores prior HUD visibility exactly")
	old_hud.hide()
	var hud := Hud.new()
	host.add_child(hud)
	var inventory := Inventory.new()
	inventory.add(&"bandage", 2)
	inventory.add(&"flare", 1)
	inventory.add(&"leather_shirt", 1)
	hud.set_inventory_model(inventory.slots, inventory.equipped)
	hud.set_inventory_counts({&"flashlight": 1, &"knife": 1, &"candy_bar": 1, &"bandage": 2, &"flare": 1})
	hud.set_health(76)
	hud.set_stamina(84)
	hud.set_wallet(45)
	var factory := PlayerFactory.new()
	var knife: Node3D = factory._make_knife_model()
	factory.free()
	var preview := Preview.new()
	host.add_child(preview)
	preview.preview_ready.connect(hud.set_item_preview)
	hud.item_preview_requested.connect(func(id: StringName): preview.show_model(knife if id == &"knife" else null, id))
	hud._select_cell(1)
	hud.toggle_inventory()
	check(hud._inventory_cell_buttons.size() == 50 and hud._quick_buttons.size() == 3, "Inventory keeps 50 cells and three quick slots")
	for frame in range(8): await process_frame
	check(preview._model != null and not preview._model.find_children("*", "MeshInstance3D", false, false).is_empty(), "Selected worn knife preview clones actual model meshes")
	check(preview._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and hud._inventory_preview.texture != null, "Item preview renders once then stops drawing")
	var request_number: int = preview._request
	hud._select_cell(1)
	check(preview._request == request_number, "Selecting the same item does not rerender its model")
	await snap("inventory")
	check(hud._inventory_root.get_global_rect().end.y < root.get_visible_rect().size.y, "Inventory including item preview fits the screen")
	if DisplayServer.get_name() != "headless":
		preferences.fullscreen = true
		preferences.apply(true)
		await process_frame
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen preference changes the real window")
		preferences.fullscreen = false
		preferences.apply(true)
		await process_frame
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Windowed preference restores the real window")
	var report := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/horror-menu-tests.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "kind": "Isolated native menu and inventory fixture; no human playtest"}, "  "))
	report.close()
	knife.free()
	host.queue_free()
	await process_frame
	print("Horror menu: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
