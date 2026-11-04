extends SceneTree
## Automated controller-driven traversal in the actual recovered scene.
## Not human playtesting; no player saves are read or written.
var game: Node3D
var audit: Dictionary
var cells: Dictionary = {}
var report: Dictionary = {"kind": "automated controller-driven recovered-house playthrough", "checks": [], "failures": [], "positions": []}
var capture := false
var _frame_previous := 0
var _frame_stage := -1
var _stage_samples: Dictionary = {}
var _stage_warmup := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> bool:
	report.checks.append({"label": label, "passed": condition})
	if not condition: report.failures.append(label)
	print("PLAYCHECK ", label, ": ", condition)
	return condition

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	if not FileAccess.file_exists("res://data/opening_audit.json"):
		_check(false, "Prior collision audit exists")
		_finish()
		return
	audit = JSON.parse_string(FileAccess.get_file_as_string("res://data/opening_audit.json"))
	for entry in audit.get("walkable_grid", []):
		if entry.connected: cells[Vector2i(entry.cell[0], entry.cell[1])] = Vector3(entry.feet[0], entry.feet[1], entry.feet[2])
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not _check(game._loaded, "Original house scene loads"):
		_finish()
		return
	game._resume()
	if capture: process_frame.connect(_sample_performance)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for index in range(60): await physics_frame
	await _picture("after-house-entry.png")
	if not await _collect(&"phone"):
		_finish()
		return
	_check(game.progression.stage == game.progression.Stage.MESSAGE, "Mara message starts through E interaction")
	await _picture("after-mara-message.png")
	await _press_action("pause_game")
	var paused_elapsed: float = game.progression._elapsed
	await create_timer(0.25, true).timeout
	_check(paused and game.progression._elapsed == paused_elapsed, "Pause freezes the message timeline")
	await _press_action("pause_game")
	_check(not paused and game.player.active, "Resume restores player control")
	await create_timer(17.0).timeout
	_check(game.progression.warning_heard, "Interrupted warning finishes")
	var pickup_order: Array[StringName] = [&"keys", &"flashlight"]
	if OS.get_cmdline_user_args().has("--flashlight-first"): pickup_order.reverse()
	report.pickup_order = pickup_order
	for kind in pickup_order:
		if kind == &"keys" and not await _open_record_room():
			_finish()
			return
		if not await _collect(kind):
			_finish()
			return
	_check(game.progression.prepared(), "Keys and flashlight preparation completes")
	await create_timer(8.3).timeout
	_check(not game.progression.power_available, "Power fails in actual scene")
	_check(game.player.lamp.visible, "Owned flashlight lights the scene")
	await _picture("after-power-loss.png")
	await create_timer(6.2).timeout
	_check(game.progression.stage == game.progression.Stage.ENCOUNTER, "Spider encounter begins")
	_check(game.spider.visible and game.spider.is_physics_processing(), "Recovered spider is visible and physical")
	await create_timer(1.8).timeout
	# Turn the real shoulder camera toward the encounter for evidence; do not move the actor.
	for frame in range(12):
		var look: Vector3 = (game.spider.global_position + Vector3.UP * 0.4 - game.player.camera.global_position).normalized()
		game.player._pitch = clampf(asin(clampf(look.y, -1.0, 1.0)), -1.05, 0.65)
		game.player.set_view(atan2(-look.x, -look.z))
		await physics_frame
	await _picture("after-spider-encounter.png")
	if OS.get_cmdline_user_args().has("--death-retry"):
		# Respect the real damage grace period before injecting this synthetic fatal hit.
		while game.player._hurt_time > 0.0: await physics_frame
		game.player.take_damage(1000.0)
		_check(game.player.is_recovering(), "Defeat starts checkpoint recovery")
		await create_timer(1.3).timeout
		_check(game.player.health == 100.0 and not game.player.is_recovering(), "Checkpoint restores Luke health and control")
		_check(game.progression.stage == game.progression.Stage.ENCOUNTER, "Checkpoint preserves encounter milestone")
	var safe: Vector3 = game.spider.safe_exit_anchor.global_position
	if not await _walk_to(safe):
		_finish()
		return
	await create_timer(3.2).timeout
	_check(game.progression.stage == game.progression.Stage.READY_TO_LEAVE, "Physical retreat to the exit resolves encounter")
	if not await _collect(&"exit"):
		_finish()
		return
	await create_timer(2.1).timeout
	_check(game.progression.stage == game.progression.Stage.COMPLETE, "Door opening reaches Greyhaven transition")
	await _picture("after-opening-complete.png")
	game._restart()
	await process_frame
	_check(game.progression.stage == game.progression.Stage.NORMAL and not game.progression.has_keys and not game.progression.has_flashlight, "Restart clears the completed opening")
	_check(not paused and game.player.active and not game._leaving, "Restart restores movement and door interaction")
	_finish()

func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _nearest(position: Vector3) -> Vector2i:
	var best := Vector2i.ZERO
	var distance := INF
	for cell in cells:
		var next: float = cells[cell].distance_to(position)
		if next < distance:
			distance = next
			best = cell
	return best

func _route(target: Vector3) -> Array[Vector3]:
	var start := _nearest(game.player.global_position)
	var end := _nearest(target)
	var parent: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	while cursor < queue.size() and not parent.has(end):
		var current := queue[cursor]
		cursor += 1
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i = current + offset
			if not cells.has(next) or parent.has(next): continue
			query.transform = Transform3D(Basis.IDENTITY, cells[current] + Vector3.UP * 0.875)
			query.motion = cells[next] - cells[current]
			var fractions: PackedFloat32Array = space.cast_motion(query)
			if not fractions.is_empty() and fractions[0] > 0.99:
				parent[next] = current
				queue.append(next)
	var points: Array[Vector3] = []
	if not parent.has(end): return points
	var current := end
	while current != start:
		points.push_front(cells[current])
		current = parent[current]
	return points

func _walk_to(target: Vector3) -> bool:
	var route := _route(target)
	if route.is_empty() and game.player.global_position.distance_to(target) > 0.8:
		return _check(false, "Collision-safe route to " + str(target))
	for point in route:
		var frames := 0
		while Vector2(game.player.position.x - point.x, game.player.position.z - point.z).length() > 0.14 and frames < 180:
			var direction: Vector3 = point - game.player.global_position
			game.player.set_view(atan2(-direction.x, -direction.z))
			Input.action_press("move_forward")
			await physics_frame
			frames += 1
		Input.action_release("move_forward")
		if frames >= 180:
			return _check(false, "Controller traverses waypoint " + str(point))
	for frame in range(12): await physics_frame
	report.positions.append([game.player.position.x, game.player.position.y, game.player.position.z])
	return true

func _collect(kind: StringName) -> bool:
	var interaction: BlackwebInteraction
	for child in game.get_children():
		if child is BlackwebInteraction and child.kind == kind: interaction = child
	if not _check(interaction != null, "Interaction exists: " + str(kind)): return false
	var position := Vector3.ZERO
	var found := false
	for entry in audit.interactions:
		if entry.kind == str(kind) and entry.reachable:
			position = Vector3(entry.standing_point[0], entry.standing_point[1], entry.standing_point[2])
			found = true
	if not _check(found, "Reachable standing point for " + str(kind)): return false
	if not await _walk_to(position): return false
	for index in range(20):
		var direction: Vector3 = (interaction.global_position - game.player.camera.global_position).normalized()
		game.player._pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -1.05, 0.65)
		game.player.set_view(atan2(-direction.x, -direction.z))
		await physics_frame
	game.player._update_focus()
	if not _check(game.player._focused == interaction, "Camera/reach selects " + str(kind)):
		var ray := PhysicsRayQueryParameters3D.create(game.player.camera.global_position, game.player.camera.global_position - game.player.camera.global_basis.z * 4.8, 1 | 8)
		ray.collide_with_areas = true
		ray.exclude = [game.player.get_rid()]
		var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(ray)
		print("FOCUSDETAIL player=", game.player.position, " camera=", game.player.camera.global_position, " target=", interaction.position, " pitch=", game.player._pitch, " hit=", hit)
		return false
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	return true

func _open_record_room() -> bool:
	var door = game.get_node_or_null("NorthEntryDoor")
	if not _check(door != null, "Record-room door exists"): return false
	if door.opened: return true
	if not await _walk_to(Vector3(-1.72, 0.44, 2.0)): return false
	var handle: BlackwebInteraction = door.get_node("EntryHandle")
	for index in range(20):
		var direction: Vector3 = (handle.global_position - game.player.camera.global_position).normalized()
		game.player._pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -1.05, 0.65)
		game.player.set_view(atan2(-direction.x, -direction.z))
		await physics_frame
	game.player._update_focus()
	if not _check(game.player._focused == handle, "Camera/reach selects record-room handle"): return false
	await _press_action(&"interact")
	await create_timer(0.70).timeout
	return _check(door.opened, "E opens the record-room door before crossing it")

func _picture(filename: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename))

func _sample_performance() -> void:
	var now := Time.get_ticks_usec()
	if not is_instance_valid(game) or paused:
		_frame_previous = now
		return
	var stage: int = game.progression.stage
	if stage != _frame_stage:
		_frame_stage = stage
		_stage_warmup = 5
	if _frame_previous > 0 and _stage_warmup <= 0:
		if not _stage_samples.has(stage): _stage_samples[stage] = {"frame_ms": [], "draw_calls": [], "physics_ms": []}
		var row: Dictionary = _stage_samples[stage]
		row.frame_ms.append((now - _frame_previous) / 1000.0)
		row.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		row.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_stage_warmup -= 1
	_frame_previous = now

func _finish() -> void:
	if capture:
		report.performance = {"scenario": "actual rendered automated traversal; includes automation route planning and capture overhead; five frames skipped per stage transition; no GPU timer. Physics values are sampled engine monitors, not isolated tick timing.", "msaa_3d": root.msaa_3d, "render_scale_3d": root.scaling_3d_scale, "window_size": [root.size.x, root.size.y], "stages": {}}
		for stage in _stage_samples:
			var samples: Dictionary = _stage_samples[stage]
			var count: int = samples.frame_ms.size()
			if count == 0: continue
			samples.frame_ms.sort()
			samples.draw_calls.sort()
			samples.physics_ms.sort()
			report.performance.stages[game.progression.Stage.keys()[stage]] = {"samples": count, "frame_ms_median": samples.frame_ms[count / 2], "frame_ms_p95": samples.frame_ms[mini(count - 1, int(count * 0.95))], "draw_calls_median": samples.draw_calls[count / 2], "physics_ms_p95": samples.physics_ms[mini(count - 1, int(count * 0.95))]}
	Input.action_release("move_forward")
	var suffix := "flashlight-first" if OS.get_cmdline_user_args().has("--flashlight-first") else "keys-first"
	var file := FileAccess.open("res://data/playthrough_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Playthrough checks: ", report.checks.size(), "; failures=", report.failures)
	quit(0 if report.failures.is_empty() else 2)
