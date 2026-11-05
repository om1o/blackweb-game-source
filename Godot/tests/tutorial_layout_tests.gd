extends SceneTree
## Run with Godot --headless --path Godot --script res://tests/tutorial_layout_tests.gd

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _ray_clear(from: Vector3, to: Vector3, world: World3D) -> bool:
	return world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	_check(game._loaded, "Compact tutorial scene loads")
	if not game._loaded:
		quit(1)
		return
	game._resume()
	for frame in range(5): await physics_frame
	var house: Node3D = game.get_node("RecoveredHouse")
	var source_count := 0
	var orphan_collisions := 0
	for child in house.get_children():
		if child.has_meta("ue_mesh_path"): source_count += 1
		if child is StaticBody3D and str(child.name).ends_with("_Collision") and not house.has_node(NodePath(str(child.name).trim_suffix("_Collision"))):
			orphan_collisions += 1
	_check(source_count < 120, "Mansion source pieces are reduced to the compact ground floor")
	_check(orphan_collisions == 0, "Removed oversized props leave no invisible collisions")
	_check(game._tutorial_doors.size() == 4 and get_nodes_in_group("tutorial_door").size() == 4, "Four operable interior doors exist")
	var exit_count := 0
	for entry in game._layout.interactions:
		if entry.kind == "exit": exit_count += 1
	_check(exit_count == 1, "One and only one exterior exit remains")
	_check(game._tutorial_evidence.size() == 3, "Two physical papers and the vault cash cache are placed")
	_check(game._tutorial_evidence[0].global_position.x < -0.8 and game._tutorial_evidence[1].global_position.x > -0.8 and game._tutorial_evidence[1].global_position.x < 3.2, "Papers occupy two different lore rooms")
	_check(game._tutorial_evidence[2].evidence_type == "cash" and game._tutorial_evidence[2].global_position.x > 3.2, "Unmarked cash is visible in the small vault room")
	var room_samples := [Vector3(-3.0, 1.1, 0.0), Vector3(1.1, 1.1, 2.0), Vector3(1.1, 1.1, -2.0), Vector3(5.4, 1.1, -2.0), Vector3(5.4, 1.1, 2.0)]
	for sample in room_samples:
		var ground := PhysicsRayQueryParameters3D.create(sample, sample + Vector3.DOWN * 2.0, 1)
		_check(not game.get_world_3d().direct_space_state.intersect_ray(ground).is_empty(), "All five room centers have recovered floor collision")
	_check(not _ray_clear(Vector3(-1.2, 1.3, 0.0), Vector3(-0.4, 1.3, 0.0), game.get_world_3d()), "Middle spine and entry wall physically divide rooms")
	for door in game._tutorial_doors:
		var door_x: float = door.global_position.x
		var door_z: float = door.global_position.z
		var from := Vector3(door_x - 0.35, 1.45, door_z)
		var to := Vector3(door_x + 0.82, 1.45, door_z)
		_check(not _ray_clear(Vector3(from.x, 3.0, from.z), Vector3(to.x, 3.0, to.z), game.get_world_3d()),
			"%s has a solid lintel up to the ceiling" % door.name)
		_check(not _ray_clear(from, to, game.get_world_3d()), "%s blocks its doorway when closed" % door.name)
		door.toggle()
		await create_timer(0.68).timeout
		_check(door.opened and door._hinge.rotation.y < -1.35, "%s animates to its open pose" % door.name)
		_check(_ray_clear(from, to, game.get_world_3d()), "%s opens a traversable passage" % door.name)
		door.toggle()
		await create_timer(0.68).timeout
		_check(not door.opened and absf(door._hinge.rotation.y) < 0.10, "%s closes again" % door.name)
	_check(game.spider.global_position.distance_to(Vector3(5.7, 0.45, -2.15)) < 0.1, "Adult spider occupies infested rear room")
	var minis := get_nodes_in_group("mini_spider")
	_check(minis.size() >= 2 and minis[0].global_position.z < -1.2 and minis[1].global_position.z > 1.2, "Juveniles occupy separate supply and vault rooms")
	_check(is_instance_valid(game._sighting_spider) and game._sighting_spider.visible and not game._sighting_spider.active, "A harmless spider is visible before the encounter")
	game._on_stage(game.progression.Stage.PRESENCE)
	await create_timer(0.68).timeout
	_check(game.get_node("SouthEntryDoor").opened, "The supply-room door reveals the early spider when Mara's warning turns ominous")
	game._on_stage(game.progression.Stage.ENCOUNTER)
	_check(not game._sighting_spider.visible, "The sighting clears before combat spiders activate")
	var report := {"checks": checks, "failures": failures, "source_nodes_after_trim": source_count,
		"orphan_collisions": orphan_collisions, "room_count": 5, "interior_doors": game._tutorial_doors.size(), "exit_count": exit_count}
	print(JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
