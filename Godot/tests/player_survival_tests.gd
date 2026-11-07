extends SceneTree
## Real player/controller APIs in a small physics fixture, independent of the
## evolving house/vault flow. Action clocks are advanced across commit events.

const Player = preload("res://scripts/player.gd")
const Progression = preload("res://scripts/progression.gd")
var results: Array[Dictionary] = []
var failures := 0
var fixture: Node3D
var player: Player
var story: Progression

class Target:
	extends CharacterBody3D
	var health := 20.0
	var hits := 0
	var alive := true
	var impact := Vector3.ZERO
	var normal := Vector3.ZERO
	func _ready() -> void:
		add_to_group("spider")
	func is_alive() -> bool:
		return alive and health > 0.0
	func get_hurt_spheres() -> Array[Dictionary]:
		return [{"center": global_position + Vector3.UP * 0.55, "radius": 0.25}]
	func take_damage(amount: float) -> void:
		health -= amount
		hits += 1
	func receive_hit(amount: float, point: Vector3, outward: Vector3) -> void:
		impact = point
		normal = outward
		take_damage(amount)

func _initialize() -> void:
	call_deferred("_run")

func check(passed: bool, description: String) -> void:
	results.append({"passed": passed, "description": description})
	if not passed:
		failures += 1
		push_error(description)

func equip(id: StringName, slot := 2) -> bool:
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == id:
			return player.equip_inventory_cell(index, slot) and player.select_quick_slot(slot)
	return false

func item_cell(id: StringName) -> int:
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == id: return index
	return -1

func box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = position
	fixture.add_child(body)
	return body

func _run() -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	box(Vector3(12, 0.4, 12), Vector3(0, -0.2, 0))
	story = Progression.new()
	story.auto_load = false
	story.auto_save = false
	story.auto_advance_atmosphere = false
	fixture.add_child(story)
	story.set_process(false)
	player = Player.new()
	player.progression = story
	fixture.add_child(player)
	story.player = player
	player.active = true
	player.set_physics_process(false)
	await process_frame
	await physics_frame
	check(player.inventory.slots.size() == 50 and player.equipped_items().size() == 3, "Player retains fifty inventory cells and three quick slots")
	check(player.item_count(&"flashlight") == 1 and player.item_count(&"knife") == 1 and player.item_count(&"candy_bar") == 1, "The three starter tools remain owned")
	check(equip(&"candy_bar"), "Candy can be selected from an equipped slot")
	check(not player.use_selected_item() and story.notice.contains("Health is full") and player.item_count(&"candy_bar") == 1, "Full-health candy use explains refusal and keeps the bar")
	player.health = 40.0
	# The headless Dummy display cannot capture the mouse. Exercise the same
	# selected-slot API called by the native left-click handler; real capture
	# and inventory-overlay interaction require the separate native UI pass.
	check(player.use_selected_item() and player._action_kind == &"candy_bar" and is_equal_approx(player.health, 40.0), "Selected-slot use starts eating candy without instant healing")
	check(not player.use_selected_item() and not player.select_quick_slot(1), "Repeated input cannot duplicate or swap an unfinished candy action")
	player._tick_item_action(0.77)
	check(is_equal_approx(player.health, 40.0) and player.item_count(&"candy_bar") == 1, "Candy is neither consumed nor applied before the bite event")
	player._tick_item_action(0.02)
	check(is_equal_approx(player.health, 70.0) and player.item_count(&"candy_bar") == 0 and story.notice.contains("+30 HP"), "The bite heals thirty HP, consumes one bar and reports the result")
	player._tick_item_action(10.0)
	check(is_equal_approx(player.health, 70.0) and player.item_count(&"candy_bar") == 0 and player._action_kind == &"", "A large action step cannot duplicate candy healing")
	player.add_item(&"candy_bar")
	equip(&"candy_bar")
	player.health = 40.0
	player.use_selected_item()
	player._tick_item_action(0.3)
	player.take_damage(5.0)
	check(player._action_kind == &"" and player.item_count(&"candy_bar") == 1 and story.notice.contains("Interrupted"), "An injury interrupts an unfinished bite without spending the candy")
	player._tick_item_action(2.0)
	check(is_equal_approx(player.health, 35.0), "An interrupted candy action cannot later heal in the background")
	player._hurt_time = 0.0
	player.use_selected_item()
	player._tick_item_action(0.79)
	player.take_damage(5.0)
	check(player.item_count(&"candy_bar") == 0 and is_equal_approx(player.health, 60.0), "Injury after the bite keeps the committed heal and never refunds consumed candy")
	player.add_item(&"candy_bar")
	equip(&"candy_bar")
	player.health = 90.0
	player.use_selected_item()
	player.health = 100.0
	player._tick_item_action(0.9)
	check(player.item_count(&"candy_bar") == 1 and player._action_kind == &"", "Becoming fully healed before the bite keeps the unused candy")
	player.health = 98.0
	player.use_selected_item()
	player._tick_item_action(1.3)
	check(is_equal_approx(player.health, 100.0) and story.notice.contains("+2 HP"), "Candy clamps to one hundred HP and reports the actual heal")
	player.add_item(&"candy_bar")
	equip(&"candy_bar")
	player.health = 50.0
	player.use_selected_item()
	player._tick_item_action(0.2)
	player.restore_checkpoint()
	player._tick_item_action(2.0)
	check(player.item_count(&"candy_bar") == 1 and player._action_kind == &"", "Checkpoint restore cancels unfinished candy without duplicating or consuming it")

	player.reset_starting_inventory()
	player.battery_charge = 20.0
	check(not player.add_battery_pack(0.0) and not player.add_battery_pack(-10.0), "Invalid pack charge cannot create a free battery")
	check(player.add_battery_pack(35.0) and equip(&"battery_35"), "A thirty-five-percent battery can occupy one of the three quick slots")
	check(player.use_selected_item() and not player.lamp.visible and is_equal_approx(player.battery_charge, 20.0), "Battery replacement turns off the beam without instant charge")
	player._tick_item_action(1.04)
	check(player.item_count(&"battery_35") == 1 and is_equal_approx(player.battery_charge, 20.0), "A battery remains unspent until insertion")
	player._flicker_off_remaining = 0.2
	player._tick_item_action(0.02)
	check(player.item_count(&"battery_35") == 0 and is_equal_approx(player.battery_charge, 55.0) and is_zero_approx(player._flicker_off_remaining), "Insertion spends one cell, adds its exact charge and clears stale flicker")
	check(story.notice.contains("+35%") and player._item_audio._streams.has(&"battery_insert"), "Replacement gives charge feedback and a distinct insertion cue")
	player._tick_item_action(0.8)
	player._tick_equipment(0.0)
	check(player.selected_quick_item() == &"flashlight" and player.lamp.visible, "Finishing replacement returns to the equipped flashlight")
	player._tick_equipment(1.0)
	check(is_equal_approx(player.battery_charge, 54.78), "A powered flashlight drains the configured 0.22 percentage points per second")
	player.use_selected_item()
	var stored_charge := player.battery_charge
	player._tick_equipment(10.0)
	check(is_equal_approx(player.battery_charge, stored_charge) and not player.lamp.visible, "A switched-off flashlight does not drain")
	player.select_quick_slot(1)
	player._tick_equipment(10.0)
	check(is_equal_approx(player.battery_charge, stored_charge), "A stored flashlight does not drain while holding the knife")
	player.battery_charge = 22.0
	player.select_quick_slot(0)
	player._tick_equipment(5.0)
	check(player.lamp.visible and is_zero_approx(player._flicker_clock) and is_equal_approx(player.battery_charge, 20.9), "Early exploration keeps the weak torch steady while normal battery drain remains active")
	story._set_stage(story.Stage.PRESENCE)
	player.battery_charge = 8.05
	player._battery_warning_band = 1
	player.select_quick_slot(0)
	player._tick_equipment(0.5)
	check(story.notice.contains("critical"), "Crossing the critical battery threshold gives a readable warning")
	player._tick_equipment(1.1)
	check(not player.lamp.visible and player._flicker_off_remaining > 0.0, "A critically depleted flashlight has a brief visible dropout")
	player._tick_equipment(0.21)
	check(player.lamp.visible, "A low-battery dropout recovers instead of leaving the light stuck off")
	var weak_energy := player.lamp.light_energy
	player.add_battery(80.0)
	player._tick_equipment(0.0)
	check(player.lamp.light_energy > weak_energy and player.lamp.visible, "Fresh charge restores beam strength and clears flicker")
	player.battery_charge = 0.01
	player._battery_warning_band = 2
	player._tick_equipment(0.1)
	check(is_zero_approx(player.battery_charge) and not player._light_on and not player.lamp.visible and story.notice.contains("empty"), "Exhaustion switches the flashlight off and explains replacement")
	check(not player.use_selected_item() and story.notice.contains("Battery empty"), "Clicking a dead flashlight explains the missing battery")
	player.add_battery_pack(35.0)
	equip(&"battery_35")
	player.use_selected_item()
	player._tick_item_action(0.5)
	player._hurt_time = 0.0
	player.take_damage(2.0)
	player._tick_item_action(2.0)
	check(player.item_count(&"battery_35") == 1 and is_zero_approx(player.battery_charge), "Interrupted replacement keeps the uninserted cell without free charge")
	player.use_selected_item()
	player._tick_item_action(2.0)
	check(is_equal_approx(player.battery_charge, 35.0) and player.item_count(&"battery_35") == 0, "Retrying replacement consumes exactly one cell")
	player.add_battery_pack(35.0)
	equip(&"battery_35")
	player.battery_charge = 100.0
	check(not player.use_selected_item() and player.item_count(&"battery_35") == 1 and story.notice.contains("already full"), "Full batteries refuse an unnecessary replacement without waste")
	player.inventory.remove(&"flashlight")
	player.battery_charge = 20.0
	check(not player.use_selected_item() and player.item_count(&"battery_35") == 1 and story.notice.contains("need a flashlight"), "A battery cannot be spent without owning a flashlight")

	player.reset_starting_inventory()
	player.health = 100.0
	player._hurt_time = 0.0
	var before_quick := player.equipped_items()
	for id in Player.ARMOR_PIECES:
		player.add_item(id)
		check(player.equip_armor(item_cell(id)), "%s equips into its armor slot" % id)
	check(player.get_armor_state().size() == 4 and is_equal_approx(player.armor_reduction_percent(), 18.0), "Four leather pieces provide eighteen percent total mitigation")
	check(player.equipped_items() == before_quick and player.inventory.occupied_count() == 7, "Armor retains inventory ownership and does not occupy a quick slot")
	check(not player.equip_inventory_cell(item_cell(&"leather_shirt"), 0) and not player.inventory.equip_cell(item_cell(&"leather_shirt"), 0), "Armor is rejected by player and inventory quick-slot APIs")
	check(not player.equip_armor(item_cell(&"knife")) and not player.unequip_armor(&"helmet"), "Wrong items and unknown armor slots are rejected")
	var full_armor := player.get_armor_state()
	check(not player.restore_armor_state({"hood": "leather_shirt"}) and player.get_armor_state() == full_armor, "Invalid armor restoration is rejected without partial mutation")
	player.take_damage(100.0)
	check(is_equal_approx(player.health, 18.0), "Full leather armor mitigates eighteen percent while maximum health remains one hundred")
	check(player.unequip_armor(&"shirt") and player.item_count(&"leather_shirt") == 1 and is_equal_approx(player.armor_reduction_percent(), 12.0), "Removing armor preserves its inventory piece and updates mitigation")
	player.equip_armor(item_cell(&"leather_shirt"))
	player.inventory.remove(&"leather_hood")
	check(player.get_armor_state().hood == &"" and is_equal_approx(player.armor_reduction_percent(), 14.0), "A piece no longer owned cannot supply phantom protection")
	player.add_item(&"leather_hood")
	player.equip_armor(item_cell(&"leather_hood"))
	player.health = 47.0
	player.battery_charge = 13.0
	player.select_quick_slot(1)
	var saved := player.survival_snapshot()
	player.reset_starting_inventory()
	player.health = 11.0
	check(player.restore_survival_state(saved), "A valid survival snapshot restores inventory, armor and resources")
	check(is_equal_approx(player.health, 47.0) and is_equal_approx(player.battery_charge, 13.0) and player.selected_quick_index == 1, "Survival restore keeps exact health, charge and selected slot")
	check(player.inventory.occupied_count() == 7 and is_equal_approx(player.armor_reduction_percent(), 18.0), "Survival restore replaces inventory instead of duplicating armor")
	check(player.restore_survival_state(saved) and player.inventory.occupied_count() == 7, "Restoring the same snapshot twice does not duplicate supplies")
	player.select_quick_slot(0)
	player.use_selected_item()
	var saved_off := player.survival_snapshot()
	player._light_on = true
	check(player.restore_survival_state(saved_off) and not player._light_on, "Survival restoration preserves an intentionally switched-off flashlight")
	player.restore_survival_state(saved)
	var invalid := saved.duplicate(true)
	invalid.armor.hood = "leather_shirt"
	var before_bad := player.survival_snapshot()
	check(not player.restore_survival_state(invalid) and player.survival_snapshot() == before_bad, "Invalid saved armor rejects the complete transaction without partial reset")
	invalid = saved.duplicate(true)
	invalid.health = -1.0
	check(not player.restore_survival_state(invalid), "Negative saved health is rejected")
	invalid = saved.duplicate(true)
	invalid.selected_quick_index = 3
	check(not player.restore_survival_state(invalid), "A saved fourth quick slot is rejected")
	invalid = saved.duplicate(true)
	invalid.version = 1.5
	check(not player.restore_survival_state(invalid), "A fractional survival version cannot masquerade as the current version")
	invalid = saved.duplicate(true)
	invalid.health = 0.0
	check(player.restore_survival_state(invalid) and player.is_recovering() and is_zero_approx(player.health), "An explicit zero-health snapshot remains recovering instead of granting free health")
	player.restore_survival_state(saved)
	player.reset_starting_inventory()
	check(is_zero_approx(player.armor_reduction_percent()) and player.inventory.occupied_count() == 3, "A new-game inventory reset clears armor rather than retaining phantom protection")

	# World-space hurt spheres put contact on the visible body surface. The
	# nearest corpse, hidden target and stale action must not steal a knife hit.
	player.health = 100.0
	player._hurt_time = 0.0
	player.select_quick_slot(1)
	var target := Target.new()
	target.position = Vector3(0, 0, -1.6)
	fixture.add_child(target)
	var corpse := Target.new()
	corpse.alive = false
	corpse.position = Vector3(0, 0, -0.9)
	fixture.add_child(corpse)
	await physics_frame
	check(player.use_selected_item() and target.hits == 0, "Knife input starts an action without immediate damage")
	# The authored slash commits at 0.28 s; sample just before and after it.
	player._tick_item_action(0.27)
	check(target.hits == 0, "Knife cannot hit before its delayed contact event")
	player._tick_item_action(0.02)
	check(target.hits == 1 and is_equal_approx(target.health, 16.0) and corpse.hits == 0, "A worn knife hits the living surface for four damage and skips the nearer corpse")
	check(absf(target.impact.distance_to(target.global_position + Vector3.UP * 0.55) - 0.25) < 0.001 and target.normal.z > 0.9, "Knife forwards the measured surface contact and outward normal to impact effects")
	player._tick_item_action(2.0)
	check(target.hits == 1, "Advancing a completed slash cannot repeat its damage")
	var wall := box(Vector3(4, 2, 0.12), Vector3(0, 1, -0.7))
	await physics_frame
	await physics_frame
	check(not player._knife_strike() and target.hits == 1, "Solid world geometry blocks melee even when a hurt sphere is in reach")
	wall.queue_free()
	await process_frame
	await physics_frame
	target.position.z = -2.0
	check(not player._knife_strike(), "A hurt sphere wholly beyond knife reach cannot be hit")
	target.position.z = 0.9
	check(not player._knife_strike(), "A target behind the aimed slash cannot be hit")
	await _finish()

func _finish() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player._cancel_item_action()
	player._item_audio.silence()
	fixture.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/player-survival-tests.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"checks": results.size(), "failures": failures, "results": results}, "  "))
		file.close()
	print("Player survival: %d checks, %d failures" % [results.size(), failures])
	quit(0 if failures == 0 else 1)
