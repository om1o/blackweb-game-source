extends SceneTree
const State = preload("res://scripts/objective_state.gd")
const Covers = preload("res://scripts/item_covers.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var story = load("res://scripts/progression.gd").new()
	story.auto_load = false
	story.auto_save = false
	story.requires_vault = true
	root.add_child(story)
	story.set_process(false)
	check(State.describe(story).target_room == 0, "Arrival points to the phone room")
	story.stage = 2
	check(State.describe(story).title == "Find the vault key", "Preparation first asks for the physical key")
	story.has_keys = true
	check(State.describe(story).target_room == 0, "Spare cells retain their own step")
	story.has_flashlight = true
	check(State.describe(story).target_room == 2 and State.describe(story, true).target_room == 4, "Reading the hidden note moves the search from records to the vault")
	for stage in range(8):
		story.stage = stage
		check(not JSON.stringify(State.describe(story)).contains("0417"), "Objective state never reveals the hidden code at stage %d" % stage)
	story.stage = 5
	check(State.describe(story).urgent and State.describe(story).target_room == -1, "Combat has an urgent objective without enemy radar")
	story.stage = 6
	story.has_exit_keys = true
	check(State.describe(story).title.contains("silk"), "Exit still requires clearing the lock")
	story.exit_web_cleared = true
	check(State.describe(story).title == "Leave the house", "Ready exit becomes the final step")
	var map = load("res://scripts/house_map.gd").new()
	root.add_child(map)
	map.set_process(false)
	for index in range(5):
		var center: Vector2 = map.ROOMS[index].get_center()
		check(map.room_at(Vector3(center.x,0,center.y)) == index, "Map room %d agrees with the five-room geometry" % index)
	map.restore_explored([0,2,4,-1,8,1.5,"3"])
	check(map.visited.size() == 3 and not map.visited.has(3), "Map restores only valid integral room IDs")
	check(map.project_point(Vector3(-5.6,0,-4.25)).is_equal_approx(map.map_rect().position), "Minimap projection uses surveyed top-left bounds")
	map.set_expanded(true)
	check(map.project_point(Vector3(8.8,0,4.25)).is_equal_approx(map.map_rect().end), "Expanded map preserves the same survey bounds")
	var hud = load("res://scripts/status_hud.gd").new()
	root.add_child(hud)
	var bag = load("res://scripts/inventory_grid.gd").new()
	for id in [&"battery_35",&"bandage",&"flare",&"leather_shirt",&"leather_pants",&"leather_hood",&"leather_shoes"]: bag.add(id,1)
	hud.set_inventory_model(bag.snapshot(),bag.equipped)
	hud.toggle_inventory()
	for id in Covers.IDS:
		var texture: Texture2D = Covers.texture(id)
		check(texture != null and texture.get_width() == 256, "Actual-model cover loads: " + str(id))
	check(Covers.texture(&"battery_1") == Covers.texture(&"battery_100"), "Battery charge variants share one cached model cover")
	check(hud._inventory_cell_covers.size() == 50 and hud._quick_covers.size() == 3, "All 50 backpack cells and three quick slots support model covers")
	check(hud._inventory_cell_covers[1].texture == Covers.texture(&"knife") and hud._inventory_cell_buttons[1].text == "", "Knife cell uses its model, without a glyph or text cover")
	hud._select_cell(2)
	check(hud._inventory_preview.texture == Covers.texture(&"candy_bar"), "Selected-item inspection shares the baked candy model cover")
	check(hud.find_children("*","SubViewport",true,false).is_empty(), "Inventory covers allocate no per-cell render viewports")
	await process_frame
	await process_frame
	check(hud._inventory_root.position.y >= 0 and hud._inventory_root.position.y+hud._inventory_root.size.y <= root.get_visible_rect().size.y+1, "Inventory fits vertically within the game canvas")
	print(JSON.stringify({"suite":"field_ui","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
