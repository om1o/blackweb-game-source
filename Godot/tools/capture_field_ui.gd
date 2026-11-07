extends SceneTree
class MapPlayer:
	extends Node3D
	var active := true
	var camera := Camera3D.new()
class MapDoor:
	extends Node
	var opened := false
	var locked := false
var output := ""
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	load("res://scripts/horror_theme.gd").apply_theme(canvas)
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/generated/blackweb_menu_corridor_v1.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(.35,.35,.35,1)
	canvas.add_child(backdrop)
	var player := MapPlayer.new()
	player.position = Vector3(1.2,.44,2.1)
	root.add_child(player)
	player.add_child(player.camera)
	player.camera.rotation.y = -.5
	var world := Node.new()
	root.add_child(world)
	var vault := MapDoor.new()
	vault.name = "RearNorthDoor"
	vault.locked = true
	world.add_child(vault)
	var record_door := MapDoor.new()
	record_door.name = "NorthEntryDoor"
	record_door.opened = true
	world.add_child(record_door)
	var story = load("res://scripts/progression.gd").new()
	story.auto_load = false
	story.auto_save = false
	root.add_child(story)
	story.set_process(false)
	story.stage = 2
	story.warning_heard = true
	story.requires_vault = true
	var tracker = load("res://scripts/objective_bar.gd").new()
	canvas.add_child(tracker)
	tracker.update_state(story)
	tracker.gameplay_visible = true
	var map = load("res://scripts/house_map.gd").new()
	canvas.add_child(map)
	map.player = player
	map.world = world
	map.progression = story
	map.restore_explored([0,2])
	map.objective_state = tracker.state
	var hud = load("res://scripts/status_hud.gd").new()
	canvas.add_child(hud)
	var inventory = load("res://scripts/inventory_grid.gd").new()
	for id in [&"battery_35",&"bandage",&"flare",&"leather_shirt",&"leather_pants",&"leather_hood",&"leather_shoes"]: inventory.add(id,2 if id == &"bandage" else 1)
	hud.set_inventory_model(inventory.snapshot(),inventory.equipped)
	hud.set_inventory_counts({&"flashlight":1,&"knife":1,&"candy_bar":1,&"battery":1,&"bandage":2,&"flare":1})
	hud.set_objective(tracker.text)
	await capture("native-hud")
	map.set_expanded(true)
	tracker.gameplay_visible = false
	await capture("native-map")
	map.set_expanded(false)
	hud.toggle_inventory()
	hud._select_cell(1)
	await capture("native-inventory")
	print("FIELD_UI_NATIVE_CAPTURED")
	quit()
func capture(name: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
