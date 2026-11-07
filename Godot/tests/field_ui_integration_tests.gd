extends SceneTree
var failures: Array[String] = []
var checks := 0
var output := ""
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
func press(game: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	game._input(event)
func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	check(game._loaded, "House loads the redesigned UI")
	if not game._loaded:
		quit(1)
		return
	game._resume()
	await process_frame
	game.progression.stage = 2
	game.progression.warning_heard = true
	game._refresh_objective()
	check(game.objective.text == "Find the vault key" and game.house_map.objective_state.target_room == 2, "Objective tracker and map share the current search area")
	await capture("field-hud")
	press(game,KEY_M)
	check(paused and game.house_map.expanded and not game.player.active, "M opens map and safely pauses combat")
	await capture("field-map")
	press(game,KEY_ESCAPE)
	check(not paused and not game.house_map.expanded and game.player.active, "Escape returns map to gameplay")
	press(game,KEY_M)
	press(game,KEY_I)
	check(not game.house_map.expanded and game.status_hud.is_inventory_open() and paused, "I switches from expanded map to backpack without resuming combat")
	game._toggle_inventory()
	for id in [&"battery_35",&"bandage",&"flare",&"leather_shirt",&"leather_pants",&"leather_hood",&"leather_shoes"]: game.player.inventory.add(id,2 if id in [&"bandage",&"flare"] else 1)
	game._update_inventory_hud()
	game._toggle_inventory()
	game.status_hud._select_cell(1)
	await capture("field-inventory")
	check(game.status_hud._inventory_preview.texture != null, "Selected worn knife renders as a model cover")
	game.status_hud._on_quick_button(2)
	check(game.player.equipped_items()[2] == &"knife" and game.player.inventory.count(&"knife") == 1, "Model covers preserve equip swap and item ownership")
	game.status_hud._select_cell(10)
	check(game.status_hud._inventory_preview.texture == null, "Empty cell clears the model inspection")
	game._toggle_inventory()
	game.house_map.restore_explored([0,2,4])
	game.player.global_position = Vector3(5,.44,2)
	game.house_map._process(.2)
	check(game.house_map.room == 4 and game.house_map.visited.has(2), "Survey retains explored rooms and follows the player")
	var campaign = load("res://scripts/tutorial_campaign.gd").new()
	campaign.save_path = "user://field_ui_save_roundtrip.json"
	var world := {"seed":42,"pickups":{},"storage":{},"explored_rooms":game.house_map.visited.keys()}
	check(campaign.save_state(game.progression.snapshot(),game.player.survival_snapshot(),world), "Exploration saves with existing survival data")
	check(campaign.load_state(), "Campaign reload accepts the saved survey")
	# JSON numbers load as floats; exercise the production map restore path.
	game.house_map.restore_explored(campaign.loaded.get("world", {}).get("explored_rooms", []))
	check(game.house_map.visited.has(4) and game.house_map.visited.has(2), "Exploration survives campaign reload")
	world.explored_rooms = [0,"not a room"]
	check(not campaign.save_state(game.progression.snapshot(),game.player.survival_snapshot(),world), "Malformed map state cannot overwrite the previous campaign")
	game._restart()
	check(game.house_map.visited.size() == 1 and not game.house_map.expanded, "New game resets map exploration and modal state")
	print(JSON.stringify({"suite":"field_ui_integration","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
