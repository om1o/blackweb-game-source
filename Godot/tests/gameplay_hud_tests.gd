extends SceneTree
## Run: Godot --headless --path <project> --script res://tests/gameplay_hud_tests.gd

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
	check(game._loaded, "Recovered house loads with new controls and HUD")
	if not game._loaded:
		_finish()
		return
	game._resume()
	for frame in range(5): await physics_frame
	check(game.status_hud._slot_labels.size() == 3, "HUD exposes exactly three item slots")
	check(game.status_hud._slot_labels[0].text.contains("FLASHLIGHT"), "First slot is flashlight")
	check(game.status_hud.layout_index == 2, "Chosen Minimal status HUD is the default")
	check(game.status_hud._slot_labels[1].text.contains("WORN KNIFE") and game.status_hud._slot_labels[2].text.contains("CANDY BAR"), "Starter knife and candy occupy slots two and three")
	for index in range(4):
		game._set_hud_layout(index)
		check(game.status_hud.layout_index == index and game.status_hud._slot_labels.size() == 3 and game.status_hud._health_bar != null and game.status_hud._battery_bar != null, "HUD layout %d shows health, stamina, battery, and three slots" % (index + 1))
	game.status_hud.set_stamina(64.0)
	check(is_equal_approx(game.status_hud._stamina_bar.value, 64.0), "Stamina bar follows player value")
	game.status_hud.set_flashlight(true, true)
	check(game.status_hud._slot_labels[0].text.contains("ON"), "Owned flashlight reports on state")
	var fixtures := get_nodes_in_group("storage")
	check(fixtures.size() == 2, "Drawer and cabinet are present in loaded house")
	for fixture in fixtures:
		var clues: Array[String] = []
		fixture.clue_found.connect(func(text: String): clues.append(text))
		var stage_before: int = game.progression.stage
		check(fixture.collision_layer == 8 and fixture.prompt().contains("Open"), "%s can be focused and opened" % fixture.name)
		fixture.interact()
		await create_timer(0.6).timeout
		check(fixture.opened and fixture.prompt().contains("Search"), "%s opens and offers a search" % fixture.name)
		check(fixture._moving.position.z < -0.34 if fixture.storage_kind == &"drawer" else fixture._moving.rotation.y > 1.1, "%s reaches its open pose" % fixture.name)
		fixture.interact()
		check(fixture.opened and fixture.prompt().contains("Close"), "%s can be searched once before closing" % fixture.name)
		fixture.interact()
		await create_timer(0.6).timeout
		check(not fixture.opened and fixture._moving.position.z > -0.04 if fixture.storage_kind == &"drawer" else fixture._moving.rotation.y < 0.1, "%s closes again" % fixture.name)
		check(game.progression.stage == stage_before, "%s does not alter opening gates" % fixture.name)
		if fixture.storage_kind == &"drawer":
			check(clues.size() == 1 and clues[0].contains("prisoner tissue") and clues[0].contains("demonic presence"), "Optional drawer clue reveals experiment premise")
			fixture.interact()
			check(clues.size() == 1, "Clue is discovered only once")
	for fixture in fixtures:
		var focus_found := false
		for offset in [Vector3(0, 0, -1.2), Vector3(-0.35, 0, -1.2), Vector3(0.35, 0, -1.2)]:
			game.player.global_position = Vector3(fixture.global_position.x + offset.x, 0.44, fixture.global_position.z + offset.z)
			game.player.velocity = Vector3.ZERO
			for frame in range(12):
				var direction: Vector3 = (fixture.global_position - game.player.camera.global_position).normalized()
				game.player._pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -1.05, 0.65)
				game.player.set_view(atan2(-direction.x, -direction.z))
				await physics_frame
			game.player._update_focus()
			if game.player._focused == fixture:
				focus_found = true
				break
		check(focus_found, "%s can be targeted from floor with shoulder camera" % fixture.name)
	game.player.global_transform = game.player.spawn_transform
	game.player.velocity = Vector3.ZERO
	for frame in range(5): await physics_frame
	Input.action_press("crouch")
	for frame in range(3): await physics_frame
	check(game.player.is_crouching() and game.player._capsule_shape.shape.height < 1.2, "Crouch lowers the collision capsule")
	Input.action_release("crouch")
	for frame in range(3): await physics_frame
	check(not game.player.is_crouching(), "Release crouch restores standing height")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in range(15): await physics_frame
	check(game.player.stamina < 100.0, "Moving sprint drains stamina")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	game.player.stamina = 100.0
	for frame in range(3): await physics_frame
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	check(game.player.velocity.y > 0.0 and game.player.stamina <= 91.0, "Grounded jump launches and costs stamina")
	Input.action_release("jump")
	_finish()

func _finish() -> void:
	var file := FileAccess.open("res://data/gameplay_hud_test_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"kind": "automated headless gameplay and HUD verification", "checks": checks, "failures": failures, "results": results}, "  "))
		file.close()
	print("Gameplay HUD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
