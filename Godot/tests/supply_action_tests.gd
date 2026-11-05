extends SceneTree
## Verify delayed effects, input locks and interruption on actual house player.

var results: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	results.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _equip(player: BlackwebPlayer, id: StringName) -> bool:
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == id:
			return player.equip_inventory_cell(index, 2) and player.select_quick_slot(2)
	return false

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	for frame in range(10): await physics_frame
	var player: BlackwebPlayer = game.player
	# Freeze only this controller while driving deterministic action time.
	player.set_physics_process(false)
	player.battery_charge = 20.0
	player.add_battery_pack(45.0)
	check(_equip(player, &"battery_45"), "Found battery can occupy one of three active slots")
	player._tick_equipment(0.0)
	player._update_held_item_visuals(true, 1.0)
	check(player._hand_battery.visible and not player._hand_flashlight.visible, "Selected cell is held before replacement")
	check(player.use_selected_item() and is_equal_approx(player.battery_charge, 20.0) and player.item_count(&"battery_45") == 1, "Replacement begins without free instant charge or consumption")
	check(not player.select_quick_slot(1) and not player.equip_inventory_cell(0, 2) and not player.use_selected_item(), "Repeated clicks and equipment changes cannot bypass an active action")
	player._tick_item_action(0.75)
	player._update_left_supply_arm()
	player._update_right_arm_pose(1.0)
	player._update_held_item_visuals(true, 1.0)
	check(player._reload_flashlight.visible and player._hand_battery.visible and not player.lamp.visible, "Replacement presents the supported torch and battery with its beam off")
	check(is_equal_approx(player.battery_charge, 20.0), "Battery gives no charge before contact")
	player._tick_item_action(0.4)
	check(is_equal_approx(player.battery_charge, 65.0) and player.item_count(&"battery_45") == 0, "Insertion applies the exact pack charge and consumes it once")
	player._tick_item_action(1.0)
	check(is_equal_approx(player.battery_charge, 65.0) and player._action_kind == &"", "Large time steps cannot duplicate charge")
	player.add_battery_pack(45.0)
	_equip(player, &"battery_45")
	player.use_selected_item()
	player._tick_item_action(0.5)
	player.restore_checkpoint()
	player._tick_item_action(2.0)
	check(player.item_count(&"battery_45") == 1 and is_equal_approx(player.battery_charge, 65.0), "Checkpoint interruption preserves uninserted cells without applying charge")
	player.battery_charge = 100.0
	check(not player.use_selected_item() and player.item_count(&"battery_45") == 1, "Full torch refuses replacement without wasting a pack")
	player.add_item(&"bandage", 2)
	player.health = 20.0
	check(_equip(player, &"bandage") and player.use_selected_item(), "Bandage starts from an equipped pack")
	player._tick_item_action(1.5)
	player._update_left_supply_arm()
	player._update_right_arm_pose(1.0)
	player._update_held_item_visuals(true, 1.0)
	check(player._hand_bandage_roll.visible and not player._hand_bandage.visible, "Applying a bandage exposes the gauze roll instead of the sealed packet")
	check(is_equal_approx(player.health, 20.0) and player.item_count(&"bandage") == 2, "Wrapping has an unhealed vulnerable interval")
	player._tick_item_action(0.85)
	check(is_equal_approx(player.health, 75.0) and player.item_count(&"bandage") == 1, "Completed wrap heals55 and removes exactly one pack")
	player._tick_item_action(1.0)
	check(player.use_selected_item(), "Remaining bandage can be used after recovery")
	player._tick_item_action(0.6)
	player.take_damage(1000.0)
	check(player._recovering and player._action_kind == &"" and player.item_count(&"bandage") == 1, "Death cancels an unfinished bandage without consuming it")
	player.restore_checkpoint()
	player.health = 100.0
	check(not player.use_selected_item() and player.item_count(&"bandage") == 1, "Full health rejects bandage without wasting it")
	player.add_item(&"flare", 1)
	check(_equip(player, &"flare") and player.use_selected_item(), "Flare starts from an equipped stick")
	player._tick_item_action(0.25)
	check(player._flare_remaining <= 0.0 and player.item_count(&"flare") == 1, "Flare stays unlit until its ignition event")
	player._tick_item_action(0.35)
	check(is_equal_approx(player._flare_remaining, 10.0) and player.item_count(&"flare") == 0, "Ignition starts ten seconds of light and consumes the stick")
	player._tick_item_action(1.0)
	player.health = 40.0
	# Use the real house collider as the reference, then start the next action
	# one metre above it. The player's frozen controller cannot hide a bad drop
	# endpoint by falling back to the floor while its tween is running.
	var floor_query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.2, player.global_position + Vector3.DOWN * 5.0, 1, [player.get_rid()])
	var floor_hit := player.get_world_3d().direct_space_state.intersect_ray(floor_query)
	player.global_position += Vector3.UP
	var remaining_before_drop: float = player._flare_remaining
	check(_equip(player, &"bandage") and player.use_selected_item() and is_instance_valid(player._placed_flare), "A burning flare is put down to free both hands for a bandage")
	player._update_held_item_visuals(true, 1.0)
	check(not player._hand_flare.visible and player._placed_flare.visible and player._flare_remaining > 0.0, "Put-down flare stays alight without intersecting the working hands")
	await create_timer(0.30).timeout
	await process_frame
	var landed_on_floor := not floor_hit.is_empty() and is_instance_valid(player._placed_flare) and absf(player._placed_flare.global_position.y - (floor_hit.position.y + 0.04)) < 0.015
	check(landed_on_floor and player.global_position.y > floor_hit.position.y + 0.8 and is_equal_approx(player._flare_remaining, remaining_before_drop) and player._action_kind == &"bandage", "An airborne supply action drops its flare onto the actual house floor without changing fuel or action timing")
	player._cancel_item_action()
	player._tick_equipment(10.1)
	check(not player._flare_light.visible and player._flare_remaining == 0.0 and player._placed_flare == null, "Flare light and placed prop end after fuel runs out")
	var output := ProjectSettings.globalize_path("res://../Evidence/supply-action-tests.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "headless integrated action checks", "checks": results.size(), "failures": failures, "results": results}, "  "))
	file.close()
	print("Supply actions: %d checks, %d failures" % [results.size(), failures])
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if failures == 0 else 1)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)
