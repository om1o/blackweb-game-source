extends SceneTree
## External, read-only workload against source or a named PCK. Writes Evidence only.
## --main-pack <Blackweb.pck> --script <absolute script> -- --output=<absolute JSON>
## --validate-route disables rendering evidence, not collision or encounter AI.

const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var game: Node3D
var cells: Dictionary = {}
var adjacency: Dictionary = {}
var paths: Array = []
var mini_spiders: Array = []
var output_path := "D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/tutorial-route-performance.json"
var validation := false
var with_armor := false
var concurrent_game_pid := 0
var source_commit := "not supplied; see runtime file hashes"
var measuring := false
var previous_usec := 0
var started_usec := 0
var leg := "setup"
var mode := "setup"
var rows: Array = []
var report := {"schema": 1, "kind": "scripted five-room rendered workload", "failures": [], "events": [], "route": [], "knife_actions": 0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
		if arg == "--validate-route": validation = true
		if arg == "--with-armor": with_armor = true
		if arg.begins_with("--concurrent-game-pid="): concurrent_game_pid = int(arg.trim_prefix("--concurrent-game-pid="))
		if arg.begins_with("--source-commit="): source_commit = arg.trim_prefix("--source-commit=")
	if not output_path.replace("\\", "/").begins_with("D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/"):
		printerr("Output must remain inside this project's Evidence directory")
		quit(3)
		return
	validation = validation or DisplayServer.get_name() == "headless"
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		report.failures.append("Scene failed to load")
		_finish()
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if with_armor:
		for item in game.player.ARMOR_PIECES:
			game.player.add_item(item)
			for cell in range(game.player.inventory.slots.size()):
				if game.player.inventory.item_at(cell) == item:
					game.player.equip_armor(cell)
					break
	mini_spiders = get_nodes_in_group("mini_spider")
	for door_name in ["NorthEntryDoor", "RearNorthDoor", "SouthEntryDoor", "RearSouthDoor"]:
		var door := game.get_node_or_null(door_name)
		if door == null:
			report.failures.append("Missing interior door " + door_name)
		elif not door.opened:
			# Narrative gating is covered by tutorial_journey_tests. This workload
			# opens doors before timing to measure the full physical house route.
			door.locked = false
			door.toggle()
	for index in 60: await physics_frame
	_build_graph()
	report.grid_cells = _vectors(cells.values())
	report.props = []
	for prop in game.get_children():
		if not prop is Node3D or prop.scene_file_path.is_empty(): continue
		var bounds: AABB
		var has_bounds := false
		for mesh in prop.find_children("*", "MeshInstance3D", true, false):
			var world_bounds: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = bounds.merge(world_bounds) if has_bounds else world_bounds
			has_bounds = true
		if has_bounds: report.props.append({"path": str(prop.get_path()), "scene": prop.scene_file_path, "position": _vector(prop.position), "bounds_min": _vector(bounds.position), "bounds_max": _vector(bounds.end)})
	var destinations := [
		{"name": "entry_lore", "point": Vector3(-2.15, 0.425, 0.05), "seconds": 3.0, "knife": false},
		{"name": "record_lore", "point": Vector3(1.0, 0.425, 1.6), "seconds": 4.0, "knife": false},
		{"name": "vault_spider", "point": Vector3(5.2, 0.425, 2.0), "seconds": 4.0, "knife": false},
		{"name": "return_record", "point": Vector3(1.0, 0.425, 1.6), "seconds": 0.0, "knife": false},
		{"name": "entry_crossing", "point": Vector3(-2.6, 0.425, -2.0), "seconds": 0.0, "knife": false},
		{"name": "supply_spider", "point": Vector3(1.4, 0.425, -1.6), "seconds": 4.0, "knife": true},
		{"name": "infested_spider", "point": Vector3(5.5, 0.425, -1.6), "seconds": 5.0, "knife": true},
		{"name": "return_supply", "point": Vector3(1.4, 0.425, -1.6), "seconds": 0.0, "knife": false},
		{"name": "exit_return", "point": Vector3(-3.0, 0.425, 0.8), "seconds": 3.0, "knife": false},
	]
	var route_start: Vector3 = game.player.global_position
	for destination in destinations:
		var path := _route(route_start, destination.point)
		if path.is_empty() or path.back().distance_to(destination.point) > 0.70:
			report.failures.append("No static collision route to " + destination.name + "; nearest=" + str(cells.get(_nearest(destination.point))) + "; path=" + str(path))
			continue
		paths.append(path)
		report.route.append({"name": destination.name, "waypoints": _vectors(path), "dwell_seconds": destination.seconds, "knife": destination.knife})
		route_start = path.back()
	if not report.failures.is_empty():
		_finish()
		return
	# Keep real attack/collision/animation work active without a checkpoint scene
	# reload truncating late-room samples. This is NOT a balance/playthrough test.
	game.player.health = 1000.0
	game.progression._set_stage(game.progression.Stage.ENCOUNTER)
	for index in 180: await physics_frame
	var from_package := OS.get_cmdline_args().has("--main-pack")
	var package_sha256 := "not applicable; source checkout"
	if from_package:
		var pack_index := OS.get_cmdline_args().find("--main-pack")
		package_sha256 = FileAccess.get_sha256(OS.get_cmdline_args()[pack_index + 1])
	var source_hashes: Dictionary = {}
	for source_file in ["main.gd", "player.gd", "tutorial_house.gd", "mini_spider.gd", "spider.gd", "house_dressing.gd", "environment_surfaces.gd", "modeled_silk.gd", "house_batching.gd", "locomotion_pose.gd", "props.gd", "supply_models.gd", "storage.gd", "horror_menu.gd", "menu_settings.gd", "item_preview.gd", "armor_visuals.gd", "progression.gd"]:
		if FileAccess.file_exists("res://scripts/" + source_file): source_hashes[source_file] = FileAccess.get_sha256("res://scripts/" + source_file)
	report.metadata = {
		"utc": Time.get_datetime_string_from_system(true), "process_id": OS.get_process_id(),
		"validation_only": validation, "engine": Engine.get_version_info(),
		"adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"display_driver": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"window_size": [root.size.x, root.size.y], "content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
		"viewport_texture_size": [root.get_texture().get_width(), root.get_texture().get_height()],
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"msaa_3d": root.msaa_3d, "render_scale_3d": root.scaling_3d_scale,
		"runtime_origin": "frozen PCK" if from_package else "current source checkout with uncommitted changes",
		"package_sha256": package_sha256,
		"base_source_commit": source_commit, "runtime_script_sha256": source_hashes,
		"concurrent_game_pid": concurrent_game_pid, "other_processes_left_untouched_by_harness": true,
		"health_budget_at_setup": 1000, "health_at_sample_start": game.player.health, "battery_at_sample_start": game.player.battery_charge,
		"armor_loadout": game.player.get_armor_state(), "graphics_preset": game.menu.settings.active_graphics_preset(),
		"valid_grid_cells": cells.size(), "precomputed_segments": paths.size(),
		"sampling": "Monotonic process_frame intervals; includes automation and sample-collection CPU overhead. Physics monitor is a cached one-second maximum, not an individual physics tick; draw values are supplemental monitors, not isolated GPU timers. No timed screenshots, logging, file I/O, graph/path construction, teleports, healing, or performance configuration changes.",
		"workload": "Four interior doors opened in setup; real encounter activated; 1000 HP prevents checkpoint reload; original 22-point starter battery, normal collision/AI/damage/animations; controller walk, room camera pans and knife actions.",
		"limitations": ["Another native game is present; shared renderer contention applies." if concurrent_game_pid > 0 else "No other Godot renderer was observed at launch; desktop apps and ordinary OS scheduling still share the device.", "One scripted route is not a sustained thermal benchmark, narrative playthrough, or minimum-spec certification.", "Frame intervals include VSync/presentation pacing and CPU/GPU scheduling, not GPU execution time.", "Headless runs validate traversal only and must never be reported as rendering performance."]
	}
	print("ROUTE_PROFILE_READY pid=", OS.get_process_id(), " validation=", validation, " adapter=", report.metadata.adapter)
	if not validation:
		await RenderingServer.frame_post_draw
		var start_image := root.get_texture().get_image()
		report.metadata.framebuffer_image_size_at_start = [start_image.get_width(), start_image.get_height()]
		start_image.save_png(output_path.trim_suffix(".json") + "-start.png")
	for index in 60: await physics_frame
	# Keep the getter as diagnostic metadata; framebuffer readback dimensions
	# above are authoritative when this getter reports an outdated backing size.
	report.metadata.viewport_texture_size_at_measurement_start = [root.get_texture().get_width(), root.get_texture().get_height()]
	process_frame.connect(_sample_frame)
	started_usec = Time.get_ticks_usec()
	previous_usec = 0
	measuring = true
	for index in destinations.size():
		leg = destinations[index].name
		mode = "walk"
		_event("leg_start")
		if not await _walk(paths[index]): break
		mode = "knife" if destinations[index].knife else "pan"
		_event("arrived")
		await _dwell(destinations[index].seconds, destinations[index].knife)
		_event("leg_end")
	measuring = false
	Input.action_release("move_forward")
	report.metadata.viewport_texture_size_at_measurement_end = [root.get_texture().get_width(), root.get_texture().get_height()]
	if not validation:
		await RenderingServer.frame_post_draw
		var end_image := root.get_texture().get_image()
		report.metadata.framebuffer_image_size_at_end = [end_image.get_width(), end_image.get_height()]
		end_image.save_png(output_path.trim_suffix(".json") + "-end.png")
	_finish()

func _build_graph() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	var space := game.player.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	report.south_door_clearance = []
	for ix in range(11):
		for iz in range(9):
			var feet := Vector3(-1.8 + ix * 0.2, 0.425, -2.8 + iz * 0.2)
			query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.875)
			query.motion = Vector3.ZERO
			var hits := space.intersect_shape(query, 8)
			var names: Array = []
			for hit in hits: names.append(str(hit.collider.get_path()))
			report.south_door_clearance.append({"feet": _vector(feet), "colliders": names})
	# The old audit's connected component predates the four interior doors;
	# construct a new compact-house grid with standing-capsule clearance.
	for x in range(63):
		for z in range(39):
			var feet := Vector3(-5.0 + x * 0.2, 0.425, -3.8 + z * 0.2)
			query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.875)
			query.motion = Vector3.ZERO
			if not space.intersect_shape(query, 1).is_empty(): continue
			cells[Vector2i(x, z)] = feet
	for cell in cells:
		var neighbors: Array = []
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if not cells.has(next): continue
			query.transform = Transform3D(Basis.IDENTITY, cells[cell] + Vector3.UP * 0.875)
			query.motion = cells[next] - cells[cell]
			var fractions := space.cast_motion(query)
			if not fractions.is_empty() and fractions[0] > 0.99: neighbors.append(next)
		adjacency[cell] = neighbors

func _nearest(point: Vector3) -> Vector2i:
	var closest := Vector2i.ZERO
	var distance := INF
	for cell in cells:
		var next_distance: float = cells[cell].distance_squared_to(point)
		if next_distance < distance:
			distance = next_distance
			closest = cell
	return closest

func _route(start_point: Vector3, target: Vector3) -> Array[Vector3]:
	var start := _nearest(start_point)
	var end := _nearest(target)
	var parent: Dictionary = {start: start}
	var queue := [start]
	var cursor := 0
	while cursor < queue.size() and not parent.has(end):
		var current: Vector2i = queue[cursor]
		cursor += 1
		for next in adjacency.get(current, []):
			if parent.has(next): continue
			parent[next] = current
			queue.append(next)
	var result: Array[Vector3] = []
	if not parent.has(end): return result
	var current := end
	while current != start:
		result.push_front(cells[current])
		current = parent[current]
	# Include the start grid cell to avoid cutting a corner when the preceding
	# destination or initial spawn lies between cells. Remove collinear interiors.
	result.push_front(cells[start])
	var compact: Array[Vector3] = []
	for index in result.size():
		if index > 0 and index + 1 < result.size():
			var a := (result[index] - result[index - 1]).normalized()
			var b := (result[index + 1] - result[index]).normalized()
			if a.dot(b) > 0.999: continue
		compact.append(result[index])
	return compact

func _walk(path: Array) -> bool:
	for point in path:
		var ticks := 0
		var last_check: Vector3 = game.player.global_position
		var allowance := maxi(300, int(game.player.global_position.distance_to(point) / 1.1 * 60.0))
		while Vector2(game.player.global_position.x - point.x, game.player.global_position.z - point.z).length() > 0.13:
			if ticks > allowance or game.player.is_recovering():
				report.failures.append("Controller blocked or recovering in " + leg + " at " + str(game.player.global_position) + "; target=" + str(point))
				Input.action_release("move_forward")
				_event("walk_failed")
				return false
			var direction: Vector3 = point - game.player.global_position
			game.player._pitch = -0.12
			game.player.set_view(atan2(-direction.x, -direction.z))
			Input.action_press("move_forward")
			if ticks > 0 and ticks % 30 == 0:
				if game.player.global_position.distance_to(last_check) < 0.06 and game.player.is_on_floor():
					Input.action_press("jump")
					_event("stalled_waypoint_jump")
				last_check = game.player.global_position
			await physics_frame
			Input.action_release("jump")
			ticks += 1
		Input.action_release("move_forward")
	return true

func _dwell(seconds: float, use_knife: bool) -> void:
	if seconds <= 0.0: return
	var ticks := int(seconds * 60.0)
	var starting_yaw: float = game.player._yaw
	if use_knife: game.player.select_quick_slot(1)
	for index in ticks:
		var phase := float(index) / maxf(1.0, float(ticks - 1))
		game.player._pitch = -0.10 + sin(phase * TAU) * 0.18
		game.player.set_view(starting_yaw + phase * TAU)
		if use_knife and index % 54 == 0:
			if game.player.use_selected_item(): report.knife_actions += 1
		await physics_frame
	if use_knife:
		while game.player._action_kind != &"": await physics_frame
		game.player.select_quick_slot(0)

func _room(position: Vector3) -> String:
	if position.x < -0.70: return "entry_lore"
	if position.x < 3.30: return "record_lore" if position.z >= 0.10 else "supply_spider"
	return "vault_spider" if position.z >= 0.10 else "infested_spider"

func _sample_frame() -> void:
	if not measuring: return
	var now := Time.get_ticks_usec()
	if previous_usec > 0:
		var active_minis := 0
		var biting_minis := 0
		for mini in mini_spiders:
			if mini.active: active_minis += 1
			if mini._bite_windup_remaining > 0.0: biting_minis += 1
		rows.append([(now - started_usec) / 1000.0, (now - previous_usec) / 1000.0,
			_room(game.player.global_position), leg, mode,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			game.spider.state, active_minis, biting_minis, game.player.health,
			game.player.battery_charge, game.player._action_kind == &"knife", paused])
	previous_usec = now

func _event(kind: String) -> void:
	report.events.append({"type": kind, "leg": leg, "seconds": (Time.get_ticks_usec() - started_usec) / 1000000.0,
		"position": _vector(game.player.global_position), "room": _room(game.player.global_position),
		"health": game.player.health, "battery": game.player.battery_charge, "progression_stage": game.progression.stage})

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _vectors(values: Array) -> Array:
	var result: Array = []
	for value in values: result.append(_vector(value))
	return result

func _stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"samples": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	var over_33 := 0
	var over_50 := 0
	for value in sorted:
		sum += float(value)
		if value > 33.333333: over_33 += 1
		if value > 50.0: over_50 += 1
	return {"samples": sorted.size(), "mean_ms": sum / sorted.size(),
		"p50_ms": sorted[maxi(0, ceili(sorted.size() * 0.50) - 1)],
		"p95_ms": sorted[maxi(0, ceili(sorted.size() * 0.95) - 1)],
		"p99_ms": sorted[maxi(0, ceili(sorted.size() * 0.99) - 1)],
		"max_ms": sorted.back(), "above_33_33_ms_percent": 100.0 * over_33 / sorted.size(),
		"above_50_ms_percent": 100.0 * over_50 / sorted.size()}

func _finish() -> void:
	measuring = false
	Input.action_release("move_forward")
	var all_frames: Array = []
	var by_room: Dictionary = {}
	var by_mode: Dictionary = {}
	var knife_frames: Array = []
	var attack_frames: Array = []
	var state_counts: Dictionary = {}
	for row in rows:
		all_frames.append(row[1])
		if not by_room.has(row[2]): by_room[row[2]] = []
		by_room[row[2]].append(row[1])
		if not by_mode.has(row[4]): by_mode[row[4]] = []
		by_mode[row[4]].append(row[1])
		if row[12]: knife_frames.append(row[1])
		if row[7] in [3, 4] or row[9] > 0: attack_frames.append(row[1])
		var state_key := str(row[7])
		state_counts[state_key] = int(state_counts.get(state_key, 0)) + 1
	for room_name in by_room: by_room[room_name] = _stats(by_room[room_name])
	for mode_name in by_mode: by_mode[mode_name] = _stats(by_mode[mode_name])
	var completed_legs := 0
	for event in report.events:
		if event.type == "leg_end": completed_legs += 1
	report.complete = report.failures.is_empty() and completed_legs == 9 and by_room.size() == 5
	report.summary = {"frame_intervals": _stats(all_frames), "by_room": by_room, "by_mode": by_mode,
		"knife_animation_frames": _stats(knife_frames), "spider_attack_frames": _stats(attack_frames), "adult_state_frame_counts": state_counts}
	report.row_columns = ["elapsed_ms", "frame_ms", "room", "leg", "mode", "draw_calls_monitor", "physics_ms_monitor", "adult_state", "active_minis", "biting_minis", "health", "battery", "knife_animation", "tree_paused"]
	report.rows = rows
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write performance evidence: ", output_path)
		quit(4)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ROUTE_PROFILE_RESULT ", JSON.stringify({"complete": report.complete, "failures": report.failures, "summary": report.summary, "output": output_path}))
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED
		_stop_audio(game)
		game.queue_free()
		await process_frame
		await create_timer(0.12).timeout
	quit(0 if report.complete else 2)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): _stop_audio(child)
