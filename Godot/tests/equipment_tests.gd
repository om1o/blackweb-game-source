extends SceneTree
## Focused flashlight, starter loadout, inventory, and enemy effect checks.

const MiniSpiderScript = preload("res://scripts/mini_spider.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	results.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	check(game._loaded, "House loads with starter equipment")
	if not game._loaded:
		await _finish(game)
		return
	game._resume()
	for frame in range(15): await physics_frame
	var player = game.player
	check(not game.progression.has_flashlight and player.flashlight_available() and player.lamp.visible, "Starter torch works before the phone and backup pickup")
	check(is_instance_valid(player._hand_flashlight) and is_instance_valid(player._view_flashlight), "Flashlight model is mounted to Luke's hand with camera fallback")
	check(player._hand_flashlight.find_child("PolyHavenSmallPlasticTorch", true, false) != null, "Imported CC0 flashlight model is used in Luke's hand")
	check(is_instance_valid(player._hand_knife) and is_instance_valid(player._hand_candy), "Knife and candy models attach to the recovered character's right hand")
	var idle_hand_world: Vector3 = player._luke_skeleton.to_global(player._luke_skeleton.get_bone_global_pose_no_override(player._right_hand_bone).origin)
	check(player._arm_pose_weight > 0.0 and player._hand_mount.global_position.y > idle_hand_world.y + 0.12, "Aiming raises the recovered right arm and held torch above idle")
	check(player._item_audio._streams.has(&"knife_swing") and player._item_audio._streams.has(&"unwrap"), "Original item action sound cues are available")
	check(player.item_count(&"knife") == 1 and player.item_count(&"candy_bar") == 1, "Worn knife and candy bar start in loadout")
	var initial_charge: float = player.battery_charge
	for frame in range(30): await physics_frame
	check(player.battery_charge < initial_charge, "Powered starter flashlight drains its battery")
	check(is_equal_approx(player.add_battery(200.0), 100.0), "Battery pickup clamps at full charge")
	check(is_equal_approx(game.status_hud._battery_bar.value, 100.0), "All HUD battery controls receive pickup changes")
	player.battery_charge = 5.0
	player._flicker_clock = 1.54
	player._tick_equipment(0.02)
	check(not player.lamp.visible and player._flicker_off_remaining > 0.0, "Low battery briefly cuts the light")
	player._tick_equipment(0.22)
	check(player.lamp.visible and player.battery_charge > 0.0, "Flashlight recovers after short flicker")
	player.battery_charge = 0.01
	player._tick_equipment(0.2)
	check(not player.lamp.visible and player.battery_charge == 0.0, "Empty battery cuts the beam")
	player.add_battery(20.0)
	check(player.lamp.visible or player._light_on, "Battery can be recharged after empty")
	check(player.select_quick_slot(1) and player.selected_quick_item() == &"knife" and not player._light_on, "Pressing slot two draws the knife and parks the torch")
	for frame in range(3): await physics_frame
	check(player._hand_knife.visible and not player._hand_flashlight.visible and game.status_hud.selected_quick_index == 1, "Worn knife remains visible in Luke's hand before attack")
	check(player.use_selected_item() and player._action_kind == &"knife", "Selected knife attacks on use input")
	for frame in range(48): await physics_frame
	check(player._hand_knife.visible and player._action_kind == &"", "Knife returns to a visible ready hold after its slash")
	check(player.select_quick_slot(2) and player.selected_quick_item() == &"candy_bar", "Slot three draws the candy bar before eating")
	for frame in range(3): await physics_frame
	check(player._hand_candy.visible and not player._hand_knife.visible, "Selected candy bar remains visible until used")
	var candy_body: Node3D = player._hand_candy.get_node("CandyBarBody")
	check(candy_body.has_node("CandyReady") and candy_body.has_node("CandyBitten") and candy_body.get_node("CandyReady").visible and not candy_body.get_node("CandyBitten").visible,
		"Held candy uses the original Blender model with an unbitten starting state")
	player.health = 50.0
	check(player.use_selected_item() and player._action_kind == &"candy_bar" and player.item_count(&"candy_bar") == 1, "Eating begins from the selected bar before item consumption")
	for frame in range(25): await physics_frame
	check(is_equal_approx(player.health, 50.0), "Candy cannot heal before the bite timing")
	var head_bone: int = player._luke_skeleton.find_bone("Bip01 Head")
	var head_world: Vector3 = player._luke_skeleton.to_global(player._luke_skeleton.get_bone_global_pose(head_bone).origin)
	check(player._hand_mount.global_position.distance_to(head_world) < 0.45 and player._hand_candy.global_position.distance_to(player._hand_mount.global_position) < 0.13, "Candy stays within Luke's grip as his hand moves near his mouth")
	var edible_tip := candy_body.to_global(Vector3(0.0685, 0.0, 0.0))
	check(edible_tip.distance_to(player._candy_mouth_world()) < 0.04, "Exposed chocolate reaches the mouth instead of sending the palm inside the face")
	for frame in range(25): await physics_frame
	check(not candy_body.get_node("CandyReady").visible and candy_body.get_node("CandyBitten").visible and player._hand_candy.visible,
		"Bite event displays the scalloped consumed model during recovery")
	for frame in range(30): await physics_frame
	check(is_equal_approx(player.health, 80.0) and player.item_count(&"candy_bar") == 0, "Candy bar heals moderately at the bite timing and is consumed")
	check(game.status_hud._slot_labels[2].text.contains("USED"), "HUD reflects eaten candy")
	player.add_item(&"bandage", 1)
	var bandage_cell := _find_cell(player, &"bandage")
	check(not player.use_item(&"bandage") and player.equip_inventory_cell(bandage_cell, 2) and player.use_quick_slot(2) and is_equal_approx(player.health, 100.0), "Findable bandage must be equipped to heal and is consumed")
	player.add_item(&"flare", 1)
	var flare_cell := _find_cell(player, &"flare")
	check(not player.use_item(&"flare") and player.equip_inventory_cell(flare_cell, 2) and player.use_quick_slot(2) and player._flare_light.visible, "Findable flare must be equipped to create short-lived light")
	game.status_hud.toggle_inventory()
	check(game.status_hud.is_inventory_open() and game.status_hud._inventory_loadout.text.contains("WORN KNIFE"), "I overlay exposes the starter loadout")
	check(game.status_hud._inventory_condition.text.contains("Health: 100") and game.status_hud._inventory_supplies.text.contains("Battery charge"), "Inventory's condition and supplies panels reflect live values")
	game.status_hud.hide_inventory()
	check(not game.status_hud.is_inventory_open(), "Inventory overlay closes")
	var placed_minis := get_nodes_in_group("mini_spider")
	check(placed_minis.size() >= 2 and not placed_minis[0].active, "Two actual-house mini spiders sleep until encounter")
	var large = game.spider
	check(large.max_health == 100.0 and large.armor == 0.0 and large.spider_type == "common", "Only common adult flesh spider is placed with 100 health and zero armor")
	check(is_instance_valid(large.visual_root) and large.mesh_scene != null and large._contact_audio._lunge.stream != null, "Recovered adult visual and original attack sounds are connected")
	large.spider_type = "common"
	large.activate(player)
	large._set_state(large.State.WINDUP)
	large._state_elapsed = 0.4
	large._update_attack_tell()
	check(large._attack_tell_light.visible and large.visual_root.position != large._visual_rest_position, "Adult windup has a readable visual telegraph")
	large._set_state(large.State.STALKING)
	player.global_position = Vector3(4.35, 0.44, -2.15)
	player.velocity = Vector3.ZERO
	for frame in range(15):
		var toward_large: Vector3 = (large.global_position + Vector3.UP * 0.3 - player.camera.global_position).normalized()
		player._pitch = clampf(asin(clampf(toward_large.y, -1.0, 1.0)), -1.05, 0.65)
		player.set_view(atan2(-toward_large.x, -toward_large.z))
		await physics_frame
	var before_beam: float = large.beam_damage_total
	player._scan_flashlight_beam(0.12)
	check(large.beam_damage_total > before_beam, "Actual shoulder-camera flashlight beam reaches large spider in house")
	large.deactivate()
	var placed_mini = placed_minis[0]
	placed_mini.activate(player)
	player.global_position = Vector3(0.62, 0.44, -2.15)
	player.velocity = Vector3.ZERO
	for frame in range(15):
		var toward_mini: Vector3 = (placed_mini.global_position + Vector3.UP * 0.14 - player.camera.global_position).normalized()
		player._pitch = clampf(asin(clampf(toward_mini.y, -1.0, 1.0)), -1.05, 0.65)
		player.set_view(atan2(-toward_mini.x, -toward_mini.z))
		await physics_frame
	player._scan_flashlight_beam(0.12)
	check(placed_mini.light_slow_remaining > 0.0, "Actual shoulder-camera beam slows placed mini spider")
	placed_mini.deactivate()
	var mini = MiniSpiderScript.new()
	mini.auto_bind_progression = false
	mini.target = player
	mini.position = Vector3(0.0, 0.44, -1.85)
	game.add_child(mini)
	mini.activate(player)
	mini.apply_flashlight_beam(1.0, 0.12)
	check(mini.max_health == 12.0 and mini.armor == 0.0 and mini.bite_windup_seconds > 0.0, "Common juvenile has explicit health, armor, and bite windup")
	check(mini.active and mini.light_speed_factor <= 0.81 and mini.light_speed_factor >= 0.79, "Mini spider beam slow is slight and bounded")
	player.global_position = Vector3(0.0, 0.44, -0.95)
	player.set_view(0.0)
	mini.global_position = Vector3(0.0, 0.44, -1.85)
	mini.walk_speed = 0.0
	for frame in range(5): await physics_frame
	var health_before_slash: float = mini.health
	check(player.use_item(&"knife") and is_equal_approx(mini.health, health_before_slash), "Knife starts a visible slash without dealing instant damage")
	for frame in range(18): await physics_frame
	check(mini.health < health_before_slash and mini.health >= health_before_slash - 4.01, "Knife deals low damage only in its slash hit window")
	check(player._hand_knife.global_position.distance_to(player._hand_mount.global_position) < 0.13, "Slashing knife stays within Luke's posed right-hand grip")
	mini.activate(player)
	mini.take_damage(4.0)
	check(mini.active and is_equal_approx(mini.health, 8.0), "Worn knife damage cannot one-shot a mini spider")
	mini.take_damage(8.0)
	check(not mini.active, "Repeated low-damage hits can defeat a mini spider")
	large.spider_type = "common"
	large.activate(player)
	large.apply_flashlight_beam(1.0, 1.0)
	var common_damage: float = large.beam_damage_total
	check(common_damage > 0.10 and common_damage < 0.13 and large._beam_slow_factor >= 0.95, "Common large spider suffers only tiny beam damage and slowing")
	large.take_damage(4.0)
	check(large.health > 95.0 and large.state != large.State.RESOLVED, "Knife cannot one-shot or resolve the large encounter")
	large.deactivate()
	large.spider_type = "armored"
	large.activate(player)
	large.apply_flashlight_beam(1.0, 1.0)
	check(large.beam_damage_total < common_damage and large._beam_slow_factor > 0.97, "Armored type resists flashlight better")
	large.deactivate()
	large.spider_type = "anomalous"
	large.activate(player)
	large.apply_flashlight_beam(1.0, 1.0)
	check(large.beam_damage_total > 0.05 and large.beam_damage_total < common_damage, "Anomalous type has intermediate beam response")
	await _finish(game)

func _finish(game: Node) -> void:
	var file := FileAccess.open("res://data/equipment_test_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"kind": "automated headless equipment verification", "checks": checks, "failures": failures, "results": results}, "  "))
		file.close()
	print("Equipment: %d checks, %d failures" % [checks, failures])
	# End this fixture's active WAV playbacks before quitting the audio server.
	# Otherwise --verbose reports playback/stream references during shutdown.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_fixture_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.10).timeout
	quit(0 if failures == 0 else 1)

func _stop_fixture_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		_stop_fixture_audio(child)

func _find_cell(player: BlackwebPlayer, item: StringName) -> int:
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == item:
			return index
	return -1
