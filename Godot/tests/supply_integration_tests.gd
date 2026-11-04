extends SceneTree
## Exercises the optional supply loop in the real house scene with saves disabled.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	_check(game._loaded, "House failed to load")
	if not game._loaded:
		_finish(game)
		return

	var player: BlackwebPlayer = game.player
	_check(game._supply_pickups.size() == 3, "Expected three authored world supplies")
	_check(game._storage_units.size() == 2, "Expected two searchable fixtures")
	_check(game.status_hud.layout_index == 2, "Minimal HUD is not the default")
	_check(player.item_count(&"knife") == 1 and player.item_count(&"candy_bar") == 1,
		"Starter gear is missing")
	_check(player.item_count(&"bandage") == 0 and player.item_count(&"flare") == 0,
		"Optional consumables were given at spawn")
	_check(player._light_on and player.battery_charge > 0.0,
		"Starter flashlight is unavailable before the phone")

	var battery: Node3D = game._supply_pickups[0]
	var bandage: Node3D = game._supply_pickups[1]
	var flare: Node3D = game._supply_pickups[2]
	_check(battery.item_id == &"battery" and bandage.item_id == &"bandage" and flare.item_id == &"flare",
		"World supply table was not applied")
	var initial_charge: float = player.battery_charge
	battery.interact()
	_check(battery.taken and player.item_count(&"battery_35") == 1 and is_equal_approx(player.battery_charge, initial_charge),
		"Battery pack did not enter inventory without auto-charging")
	battery.interact()
	_check(player.item_count(&"battery_35") == 1,
		"Battery pack duplicated after pickup")
	bandage.interact()
	flare.interact()
	_check(player.item_count(&"bandage") == 1 and player.item_count(&"flare") == 1,
		"World bandage or flare did not enter inventory")

	var drawer: BlackwebStorage = game._storage_units[0]
	var cabinet: BlackwebStorage = game._storage_units[1]
	drawer.interact()
	_check(drawer.opened and drawer._loot_rolled and game.status_hud.record_found,
		"Drawer opening failed to reveal the optional record")
	var first_drawer_roll: Array = drawer._pending_loot.duplicate(true)
	drawer.interact()
	_check(player.item_count(&"battery_30") == 1,
		"Guaranteed drawer battery pack was not collected")
	var drawer_batteries: int = player.item_count(&"battery")
	drawer.interact() # Close.
	drawer.interact() # Reopen without rerolling.
	drawer.interact() # Close again; no second search is offered.
	_check(player.item_count(&"battery") == drawer_batteries,
		"Storage contents duplicated after reopening")
	drawer.reset_loot(drawer.loot_seed)
	drawer.interact()
	_check(drawer._pending_loot == first_drawer_roll,
		"Seeded drawer roll changed after resetting to the same seed")

	cabinet.interact()
	cabinet.interact()
	_check(player.item_count(&"bandage") >= 2,
		"Guaranteed cabinet bandage was not collected")
	_check(InputMap.has_action("hotbar_1") and InputMap.has_action("hotbar_2") and InputMap.has_action("hotbar_3") and
		InputMap.has_action("inventory_toggle") and not InputMap.has_action("hotbar_4"),
		"Three quick-slot or inventory keys were not mapped")
	player.active = true
	player.health = 30.0
	var bandages_before_use: int = player.item_count(&"bandage")
	_check(not player.use_item(&"bandage") and player.item_count(&"bandage") == bandages_before_use,
		"Unequipped bandage could be used")
	_check(player.equip_inventory_cell(_find_cell(player, &"bandage"), 2),
		"Found bandage could not be equipped into quick slot three")
	var bandage_action := InputEventAction.new()
	bandage_action.action = "hotbar_3"
	bandage_action.pressed = true
	player._unhandled_input(bandage_action)
	_check(player.selected_quick_item() == &"bandage" and
		player.item_count(&"bandage") == bandages_before_use and is_equal_approx(player.health, 30.0),
		"Bandage hotkey did not draw the pack without consuming it")
	var use_click := InputEventMouseButton.new()
	use_click.button_index = MOUSE_BUTTON_LEFT
	use_click.pressed = true
	_press_use(player, use_click)
	_check(player.item_count(&"bandage") == bandages_before_use - 1 and
		is_equal_approx(player.health, 85.0), "Drawn bandage did not heal and consume on left click")
	var flares_before_use: int = player.item_count(&"flare")
	_check(player.equip_inventory_cell(_find_cell(player, &"flare"), 2),
		"Found flare could not be equipped into quick slot three")
	var flare_action := InputEventAction.new()
	flare_action.action = "hotbar_3"
	flare_action.pressed = true
	player._unhandled_input(flare_action)
	_check(player.selected_quick_item() == &"flare" and player.item_count(&"flare") == flares_before_use,
		"Flare hotkey did not draw the flare without consuming it")
	_press_use(player, use_click)
	_check(player.item_count(&"flare") == flares_before_use - 1 and
		player._flare_remaining > 0.0, "Drawn flare did not ignite and consume on left click")
	player.active = false

	player.add_battery(100.0)
	battery.reset_pickup()
	battery.interact()
	_check(battery.taken and player.item_count(&"battery_35") == 2 and is_equal_approx(player.battery_charge, 100.0),
		"Full-charge player could not store battery cells for later")
	player.active = true
	_check(player.equip_inventory_cell(_find_cell(player, &"battery_35"), 2),
		"Stored battery pack could not be equipped")
	_check(not player.use_quick_slot(2) and player.item_count(&"battery_35") == 2,
		"Full battery consumed an equipped pack")
	player.battery_charge = 65.0
	_check(player.use_quick_slot(2) and player.item_count(&"battery_35") == 1 and is_equal_approx(player.battery_charge, 100.0),
		"Equipped saved battery did not recharge by its exact amount")
	player.active = false

	var bandages_before_retry: int = player.item_count(&"bandage")
	player.restore_checkpoint()
	_check(player.item_count(&"bandage") == bandages_before_retry and battery.taken,
		"Fatal checkpoint retry duplicated or removed optional supplies")
	game._restart()
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_check(player.item_count(&"knife") == 1 and player.item_count(&"candy_bar") == 1,
		"New opening did not restore starter gear")
	_check(player.item_count(&"bandage") == 0 and player.item_count(&"flare") == 0,
		"New opening retained collected consumables")
	_check(player.item_count(&"battery") == 0 and player.equipped_items() == [&"flashlight", &"knife", &"candy_bar"],
		"New opening retained battery packs or the changed quick-slot loadout")
	_check(is_equal_approx(player.battery_charge, player.starting_battery_charge),
		"New opening did not reset flashlight charge")
	_check(not battery.taken and not bandage.taken and not flare.taken,
		"New opening did not restore world supplies")
	_check(not drawer.opened and not drawer._loot_rolled and not cabinet.opened and not cabinet._loot_rolled,
		"New opening did not reset storage")
	_check(not game.status_hud.record_found, "Optional record carried into the new opening")
	for index in range(47):
		player.add_item(StringName("qa_fill_%d" % index), 1)
	_check(player.inventory.occupied_count() == 50, "Test inventory did not reach its 50-cell limit")
	bandage.interact()
	_check(not bandage.taken and player.item_count(&"bandage") == 0,
		"Full inventory consumed a world pickup that could not fit")
	_finish(game)


func _finish(game: Node3D) -> void:
	print(JSON.stringify({"passed": failures.is_empty(), "failures": failures,
		"world_supply_count": game._supply_pickups.size() if game._loaded else 0,
		"storage_count": game._storage_units.size() if game._loaded else 0}))
	paused = false
	game.queue_free()
	quit(0 if failures.is_empty() else 1)


func _find_cell(player: BlackwebPlayer, item: StringName) -> int:
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == item:
			return index
	return -1


func _press_use(player: BlackwebPlayer, click: InputEventMouseButton) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player._unhandled_input(click)
	else:
		# The headless DisplayServer cannot capture a mouse. This is the same
		# handler reached by a real left click after drawing a quick-slot item.
		player.use_selected_item()
