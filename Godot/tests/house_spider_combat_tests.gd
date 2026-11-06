extends SceneTree
## Real house, authored doors, JSON profiles and player knife selection.
var game: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	_check(game._loaded, "The complete house loads for spider combat integration")
	if not game._loaded:
		await _finish()
		return
	game._resume()
	# New game / ignored phone / looking away must all permit a real fight.
	game.progression.set_process(false)
	game.player.set_physics_process(false)
	game.player.camera.rotation.y += PI
	game.progression._elapsed = 8.1
	game._update_early_sighting(.1)
	var starter = game._sighting_spider
	_check(starter.active and starter.visible and starter.collision_layer == 4,
		"Starting-room spider activates without camera visibility, phone, key or vault")
	_check(starter.health == 12.0 and starter.hit_damage == 4.0,
		"Starter has juvenile health and bite damage")
	starter.take_damage(4)
	_check(starter.health == 8.0, "Starter receives worn-knife damage")
	starter.take_damage(8)
	game._update_early_sighting(1)
	_check(not starter.active and starter.health == 0, "Killed starter does not respawn every frame")
	game.progression.restore_snapshot(game.progression.snapshot())
	game.progression._elapsed = 8.1
	game._update_early_sighting(.1)
	_check(starter.active and starter.health == 12, "Checkpoint reset restores a fightable starter")
	game.progression.interact(&"phone")
	_check(not starter.active, "Phone dialogue suspends the starter encounter")
	game.progression.step(20)
	game.progression._elapsed = 6.1
	game._update_early_sighting(.1)
	_check(starter.active and not game.progression.vault_unlocked, "Starter returns after phone without vault puzzle")
	game._reset_early_spider()
	game.set_process(false)
	game.progression.auto_advance_atmosphere = false
	game.progression.set_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.spider.set_process(false)
	game.spider.set_physics_process(false)
	for mini in get_nodes_in_group("mini_spider"):
		mini.set_process(false)
		mini.set_physics_process(false)
	for door in game._tutorial_doors:
		# Routing fixture: vault authorization is covered by tutorial_journey.
		# A locked door would open a paused keypad instead of its physical hinge.
		door.locked = false
		if not door.opened: door.toggle()
	await create_timer(0.75).timeout
	var all_open := true
	for door in game._tutorial_doors:
		all_open = all_open and door.opened and door._hinge.rotation.y < -1.35
	_check(all_open, "All four real interior doors complete their opening animations")
	var adult = game.spider
	var live = game.get_node("MiniSpider1")
	var corpse = game.get_node("MiniSpider2")
	var sighting = game._sighting_spider
	sighting.deactivate()
	_check(is_equal_approx(adult.max_health, 100.0) and is_equal_approx(adult.hit_damage, 35.0)
		and is_equal_approx(adult.bite_damage, 18.0), "The real adult receives its 100-HP, 35-lunge and 18-bite JSON balance")
	_check(is_equal_approx(live.max_health, 12.0) and is_equal_approx(live.hit_damage, 4.0)
		and is_equal_approx(corpse.max_health, 12.0) and is_equal_approx(corpse.hit_damage, 4.0),
		"Both placed juveniles receive twelve HP and four bite damage from the profile")
	_check(adult.navigation_points.size() == 17 and adult._navigation.points.size() == 17,
		"The house passes its seventeen doorway waypoints into the adult navigator")
	adult.position = Vector3(5.7, 0.45, -2.15)
	var entry := Vector3(-2.2, 0.425, 0.0)
	adult._navigation.advance(0.61)
	var direction: Vector3 = adult._navigation.next_direction(adult, entry)
	_check(not direction.is_zero_approx(), "The actual infested-room spawn has a floor-supported route to the entry with doors open")
	print("HOUSE_ROUTE ", JSON.stringify({"from": str(adult.position), "to": str(entry), "direction": str(direction)}))
	var rear_door = game.get_node("RearSouthDoor")
	rear_door.toggle()
	await create_timer(0.75).timeout
	adult.activate(game.player)
	adult.set_physics_process(false)
	adult.position = Vector3(4.05, 0.45, -2.0)
	await physics_frame
	_check(not adult._navigation._clear(adult, adult.position, Vector3(2.6, 0.45, -2.0)),
		"Closing the infested-room door rejects a capsule route through its physical panel")
	for tick in 60:
		await physics_frame
		adult.velocity = Vector3(-2.0, -0.5, 0.0)
		adult.move_and_slide()
	_check(adult.position.x > 3.60 and adult.position.x < 4.05,
		"The real adult collision moves toward the closed door and cannot cross it")
	adult.position = Vector3(5.7, 0.45, -2.15)
	adult.velocity = Vector3.ZERO

	game.player.position = entry
	game.player.health = 100.0
	game.player.active = true
	live.position = entry + Vector3.FORWARD * 0.80
	live.activate(game.player)
	live.set_physics_process(false)
	corpse.position = entry + Vector3.FORWARD * 0.45
	corpse.activate(game.player)
	corpse.take_damage(99.0)
	corpse.set_physics_process(false)
	sighting.position = entry + Vector3.FORWARD * 0.30
	sighting.show()
	game.player.camera.look_at(live.global_position + Vector3.UP * 0.25, Vector3.UP)
	await physics_frame
	_check(not sighting.is_alive() and not corpse.is_alive() and live.is_alive(),
		"The knife fixture contains a nearer passive sighting and corpse ahead of a live enemy")
	var struck: bool = game.player._knife_strike()
	_check(struck and is_equal_approx(live.health, 8.0),
		"The real player knife skips the nearer sighting and corpse and removes four HP from the live juvenile")
	_check(is_zero_approx(corpse.health) and is_equal_approx(sighting.health, 12.0),
		"Knife selection neither damages the decorative sighting nor damages a corpse again")
	await _finish()

func _finish() -> void:
	print(JSON.stringify({"suite": "house spider combat", "checks": checks, "failures": failures}))
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)
