extends SceneTree
## Integration audit against the recovered house, with saves disabled.
## Optional --capture renders evidence from the real player camera.
var game: Node3D
var report: Dictionary = {"kind": "recovered-level integration audit", "checks": [], "failures": []}
var capture := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	report.checks.append({"label": label, "passed": condition})
	if not condition: report.failures.append(label)

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	if OS.get_cmdline_user_args().has("--render-scale-test"): root.scaling_3d_scale = 0.85
	if OS.get_cmdline_user_args().has("--no-msaa"): root.msaa_3d = Viewport.MSAA_DISABLED
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	_check(game._loaded, "Recovered house loads")
	if not game._loaded:
		_finish()
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for index in range(120): await physics_frame
	# Audit the connected floor plan with its four interior leaves open. The
	# controller-driven playthrough below tests opening the required door itself.
	for door in game._tutorial_doors: door.toggle()
	await create_timer(0.72).timeout
	report.interior_doors_open_for_geometry_audit = game._tutorial_doors.size()
	report.static_batching = game._batching_report
	var player: CharacterBody3D = game.player
	_check(player.is_on_floor(), "Luke settles on original floor")
	_check(player.global_position.y > -1.0, "Luke stays above the basement void")
	report.spawn = _arr(player.global_position)
	_check(player._animation != null, "Luke has imported animation player")
	if player._animation != null:
		report.luke_clips = player._animation.get_animation_list()
		_check(not player._idle_clip.is_empty() and not player._walk_clip.is_empty() and not player._run_clip.is_empty(), "Luke idle, walk and run are connected")
	_check(game.spider.animation_player != null, "Spider has recovered animation player")
	if game.spider.animation_player != null: report.spider_clips = game.spider.animation_player.get_animation_list()
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	var cells: Dictionary = {}
	var origin := Vector2(-5.0, -4.0)
	var cell_size := 0.4
	var width := 40
	var depth := 28
	for ix in range(width):
		for iz in range(depth):
			var x := origin.x + ix * cell_size
			var z := origin.y + iz * cell_size
			var floor_query := PhysicsRayQueryParameters3D.create(Vector3(x, 0.85, z), Vector3(x, -0.5, z), 1)
			var floor_hit: Dictionary = space.intersect_ray(floor_query)
			if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < 0.65: continue
			var feet: Vector3 = floor_hit.position + Vector3.UP * 0.025
			query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.875)
			if space.intersect_shape(query, 1).is_empty(): cells[Vector2i(ix, iz)] = feet
	var start := Vector2i(roundi((player.position.x - origin.x) / cell_size), roundi((player.position.z - origin.y) / cell_size))
	if not cells.has(start):
		var nearest := INF
		for key in cells:
			var distance: float = cells[key].distance_to(player.position)
			if distance < nearest:
				nearest = distance
				start = key
	var initial_clear := false
	if cells.has(start) and cells[start].distance_to(player.position) < 0.65:
		query.transform = Transform3D(Basis.IDENTITY, player.position + Vector3.UP * 0.9)
		query.motion = cells[start] - player.position
		var initial_sweep: PackedFloat32Array = space.cast_motion(query)
		initial_clear = not initial_sweep.is_empty() and initial_sweep[0] > 0.99
	_check(initial_clear, "Actual spawn connects to audited floor grid")
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	if cells.has(start) and initial_clear:
		queue.append(start)
		visited[start] = true
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = current + offset
			if cells.has(neighbor) and not visited.has(neighbor):
				query.transform = Transform3D(Basis.IDENTITY, cells[current] + Vector3.UP * 0.875)
				query.motion = cells[neighbor] - cells[current]
				var fractions: PackedFloat32Array = space.cast_motion(query)
				if fractions.size() > 0 and fractions[0] > 0.99:
					visited[neighbor] = true
					queue.append(neighbor)
	report.walkable_cells = cells.size()
	report.spawn_connected_cells = visited.size()
	report.interactions = []
	for interaction in game.get_children():
		if not interaction is BlackwebInteraction: continue
		var best_distance := INF
		var best := Vector3.ZERO
		for key in visited:
			var feet: Vector3 = cells[key]
			var distance := feet.distance_to(interaction.global_position)
			if distance >= best_distance: continue
			var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 1.35, interaction.global_position, 1)
			if space.intersect_ray(ray).is_empty():
				best_distance = distance
				best = feet
		var reachable := best_distance < 2.1
		_check(reachable, "Reachable without crossing geometry: " + str(interaction.kind))
		report.interactions.append({"kind": str(interaction.kind), "position": _arr(interaction.position), "standing_point": _arr(best), "distance": best_distance if is_finite(best_distance) else -1, "reachable": reachable})
	var grid: Array = []
	for key in cells: grid.append({"cell": [key.x, key.y], "feet": _arr(cells[key]), "connected": visited.has(key)})
	report.walkable_grid = grid
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../Evidence/after-house-entry.png")
		var milliseconds: Array[float] = []
		var physics_ms: Array[float] = []
		var previous := Time.get_ticks_usec()
		for index in range(180):
			await process_frame
			var current := Time.get_ticks_usec()
			milliseconds.append((current - previous) / 1000.0)
			physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			previous = current
		milliseconds.sort()
		physics_ms.sort()
		report.performance = {"samples": 180, "render_scale_3d": root.scaling_3d_scale, "msaa_3d": root.msaa_3d, "window_size": [root.size.x, root.size.y], "scenario": "stationary entrance, actual renderer; no GPU timer available", "frame_ms_median": milliseconds[90], "frame_ms_p95": milliseconds[171], "physics_ms_p95": physics_ms[171], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	_finish()

func _arr(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _finish() -> void:
	var output_path := "res://data/opening_audit_rendered.json" if capture else "res://data/opening_audit.json"
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("Opening integration audit: ", report.checks.size(), " checks; failures=", report.failures)
	quit(0 if report.failures.is_empty() else 2)
