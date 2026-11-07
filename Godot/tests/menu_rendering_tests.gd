extends SceneTree
const Menu = preload("res://scripts/horror_menu.gd")
const Settings = preload("res://scripts/menu_settings.gd")
const Hud = preload("res://scripts/status_hud.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	results.append({"passed": value, "label": label})
	if not value: failures += 1; push_error(label)
func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hud := Label.new()
	hud.text = "Gameplay"
	host.add_child(hud)
	root.disable_3d = false
	var menu := Menu.new()
	menu.qa_mode = true
	host.add_child(menu)
	await process_frame
	check(root.disable_3d, "Visible main menu suspends only its parent viewport 3D drawing")
	check(not hud.visible, "Menu still suppresses underlying HUD")
	menu.show_page("options")
	check(root.disable_3d, "Options keeps world rendering suspended")
	menu.present("complete",false,true,true)
	check(not menu.resume_button.disabled and menu.resume_button.text == "Enter the garden", "Completing the house unlocks the outdoor encounter")
	var routing := {"boss":false,"resume":false}
	menu.boss_test_requested.connect(func(): routing.boss = true)
	menu.resume_requested.connect(func(): routing.resume = true)
	menu.resume_button.pressed.emit()
	check(routing.boss and not routing.resume, "Completed-house continue routes to garden rather than resuming the closed chapter")
	menu.hide()
	check(not root.disable_3d and hud.visible, "Hiding menu restores world drawing and HUD")
	root.disable_3d = true
	menu.show()
	menu.hide()
	check(root.disable_3d, "Menu preserves a viewport that was already disabled before opening")
	root.disable_3d = false
	menu.show()
	var separate_preview := SubViewport.new()
	host.add_child(separate_preview)
	separate_preview.own_world_3d = true
	check(not separate_preview.disable_3d and root.disable_3d, "Separate item-preview viewport is not disabled by menu ownership")
	var settings := Settings.new()
	var prior_canvas := root.canvas_transform
	var prior_size := root.content_scale_size
	settings.graphics_preset = "quality"
	settings.apply_graphics(root)
	check(is_equal_approx(root.scaling_3d_scale, 1.0) and root.msaa_3d == Viewport.MSAA_2X, "Quality uses full 3D resolution and 2x MSAA")
	settings.graphics_preset = "performance"
	root.scaling_3d_scale = .75 # An already-running old preset must be reset too.
	settings.apply_graphics(root)
	check(is_equal_approx(root.scaling_3d_scale, 1.0) and root.msaa_3d == Viewport.MSAA_DISABLED, "Performance keeps native 3D resolution and disables MSAA after the Intel comparison")
	check(root.canvas_transform == prior_canvas and root.content_scale_size == prior_size, "Graphics presets leave the 2D canvas size and transform unchanged")
	check(root.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "Presets use the compatible bilinear scaler")
	settings.configure_graphics(PackedStringArray(["--graphics=quality"]))
	settings.apply_graphics(root)
	check(settings.active_graphics_preset() == "quality" and root.scaling_3d_scale == 1.0 and root.msaa_3d == Viewport.MSAA_2X, "Explicit quality CLI overrides saved Performance")
	settings.graphics_preset = "quality"
	settings.configure_graphics(PackedStringArray(["--graphics=performance"]))
	settings.apply_graphics(root)
	check(settings.active_graphics_preset() == "performance" and root.scaling_3d_scale == 1.0 and root.msaa_3d == Viewport.MSAA_DISABLED, "Explicit performance CLI overrides saved Quality")
	settings.configure_graphics(PackedStringArray(["--graphics=unknown"]))
	check(settings.graphics_override.is_empty() and settings.active_graphics_preset() == "quality", "Invalid CLI preset does not replace a valid preference")
	check(Settings.is_intel_hd530("ANGLE (Intel, Intel(R) HD Graphics 530)"), "Automatic Performance default recognizes the actual Intel HD530 adapter")
	check(not Settings.is_intel_hd530("Intel(R) HD Graphics 630") and not Settings.is_intel_hd530("AMD Radeon RX550"), "Automatic default is limited to the specified Intel HD530")
	settings.path = "user://graphics_fixture.cfg"
	settings.graphics_preset = "performance"
	check(settings.save_preferences(), "Graphics preference saves in the isolated fixture directory")
	var loaded := Settings.new()
	loaded.path = settings.path
	loaded.load_preferences()
	check(loaded.graphics_preset == "performance", "Graphics preference survives reload")
	menu.graphics_picker.select(0)
	menu.graphics_picker.item_selected.emit(0)
	check(menu.settings.graphics_preset == "quality" and root.scaling_3d_scale == 1.0 and root.msaa_3d == Viewport.MSAA_2X, "Options graphics selector applies Quality immediately")
	menu.graphics_picker.select(1)
	menu.graphics_picker.item_selected.emit(1)
	check(menu.settings.graphics_preset == "performance" and root.scaling_3d_scale == 1.0 and root.msaa_3d == Viewport.MSAA_DISABLED, "Options graphics selector applies Performance immediately")
	menu.queue_free()
	await process_frame
	check(not root.disable_3d and hud.visible, "Removing an open menu restores world drawing and HUD")
	var kit := Hud.new()
	host.add_child(kit)
	kit.toggle_inventory()
	var old_condition: String = kit._inventory_condition.text
	var old_supplies: String = kit._inventory_supplies.text
	kit.hide_inventory()
	kit.set_health(76)
	kit.set_stamina(44)
	kit.set_battery(31, false)
	check(kit._inventory_condition.text == old_condition and kit._inventory_supplies.text == old_supplies, "Closed inventory defers text formatting while values change")
	check(kit._health_bar.value == 76 and kit._stamina_bar.value == 44 and kit._battery_bar.value == 31, "Closed inventory does not delay live gameplay meters")
	kit.toggle_inventory()
	check(kit._inventory_condition.text.contains("Health: 76") and kit._inventory_condition.text.contains("Stamina: 44") and kit._inventory_supplies.text.contains("Battery 31%"), "Every inventory reopen refreshes health stamina and battery even without a new selected item")
	var report := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/menu-rendering-tests.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "kind": "Headless state and lifecycle checks; no rendering-speed claim"}, "  "))
	report.close()
	host.queue_free()
	await process_frame
	print("Menu rendering: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
