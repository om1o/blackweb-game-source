extends SceneTree
## Run: Godot --headless --path Godot --script res://tests/inventory_50_tests.gd

const Inventory = preload("res://scripts/inventory_grid.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)


func _run() -> void:
	var bag = Inventory.new()
	_check(bag.slots.size() == 50 and bag.occupied_count() == 3, "Starter inventory has 50 cells and exactly three occupied cells")
	_check(bag.equipped == [&"flashlight", &"knife", &"candy_bar"], "Starter quick slots are flashlight, worn knife, candy")
	_check(bag.count(&"flashlight") == 1 and bag.count(&"knife") == 1 and bag.count(&"candy_bar") == 1, "Starter gear resides in the authoritative grid")
	bag.add(&"bandage", 12)
	_check(bag.count(&"bandage") == 12 and bag.occupied_count() == 5, "Consumable stacks of ten occupy real cells")
	_check(bag.equip_cell(3, 2) and bag.quick_item(2) == &"bandage" and bag.quick_item(0) == &"flashlight", "Any occupied cell can equip one of three quick slots")
	_check(bag.equip_cell(1, 2) and bag.quick_item(1) == &"bandage" and bag.quick_item(2) == &"knife", "Moving an equipped item swaps quick slots instead of duplicating")
	_check(bag.remove(&"bandage", 12) and bag.count(&"bandage") == 0 and bag.occupied_count() == 3, "Using items removes them from the same 50 cells")
	_check(not bag.equip_cell(3, 0) and not bag.remove(&"bandage"), "Empty cells and absent items cannot be equipped or consumed")
	for index in range(47):
		bag.add(StringName("test_%d" % index), 1)
	_check(bag.occupied_count() == 50 and bag.add(&"overflow", 1) == 0, "Filled 50-cell inventory rejects new item kinds")
	bag.reset()
	_check(bag.occupied_count() == 3 and bag.quick_item(2) == &"candy_bar", "New opening restores the starter grid and quick slots")

	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	_check(game._loaded, "Real house loads the 50-slot inventory")
	if not game._loaded:
		_finish()
		return
	game._resume()
	for frame in range(3): await physics_frame
	var player: BlackwebPlayer = game.player
	var hud: BlackwebStatusHud = game.status_hud
	_check(hud._inventory_cell_buttons.size() == 50 and hud._quick_buttons.size() == 3, "Interactive HUD has 50 cells and exactly three equip targets")
	_check(hud.inventory_slots.size() == 50 and hud.equipped_items == [&"flashlight", &"knife", &"candy_bar"], "HUD mirrors the player's authoritative grid")
	var pickup: BlackwebSupplyPickup = game._supply_pickups[0]
	var before_charge: float = player.battery_charge
	pickup.interact()
	_check(pickup.taken and player.item_count(&"battery_35") == 1 and is_equal_approx(player.battery_charge, before_charge), "Found battery remains a pack until equipped and used")
	var battery_cell := _find_cell(player, &"battery_35")
	_check(not player.use_item(&"battery_35"), "Backpack battery cannot be used from outside the three quick slots")
	game._toggle_inventory()
	_check(hud.is_inventory_open() and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not player.active, "Inventory opens with mouse and pauses combat")
	hud._inventory_cell_buttons[battery_cell].pressed.emit()
	hud._quick_buttons[2].pressed.emit()
	_check(player.equipped_items()[2] == &"battery_35" and hud.equipped_items[2] == &"battery_35", "Clicking a cell then quick slot equips its real item")
	game._toggle_inventory()
	_check(not hud.is_inventory_open() and not paused and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless") and player.active, "Closing inventory returns to play")
	_check(player.use_quick_slot(2) and player.item_count(&"battery_35") == 1 and is_equal_approx(player.battery_charge, before_charge), "Using the equipped pack begins replacement without instant charge or consumption")
	_check(not hud._slot_labels[2].text.contains("USED") and not hud._inventory_cell_buttons[battery_cell].text.contains("·"), "HUD keeps the pack until the battery is inserted")
	player._tick_item_action(1.1)
	_check(player.item_count(&"battery_35") == 0 and is_equal_approx(player.battery_charge, before_charge + 35.0), "Insertion recharges by the pack's authored value and consumes it once")
	_check(hud._slot_labels[2].text.contains("USED") and hud._inventory_cell_buttons[battery_cell].text.contains("·"), "HUD and backpack update after the pack is consumed")
	player._tick_item_action(0.6)
	game._restart()
	_check(player.item_count(&"battery") == 0 and player.equipped_items() == [&"flashlight", &"knife", &"candy_bar"], "Restart removes acquired packs and restores starter quick slots")
	_finish()


func _find_cell(player: BlackwebPlayer, id: StringName) -> int:
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == id:
			return index
	return -1


func _finish() -> void:
	print("Inventory 50: %d checks, %d failures" % [checks, failures.size()])
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit(0 if failures.is_empty() else 1)
