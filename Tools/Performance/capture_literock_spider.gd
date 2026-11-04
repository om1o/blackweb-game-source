extends SceneTree
## Native compact-house QA and a controlled visible/hidden frame-time probe.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Literock review: house failed to load")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var mini: Node3D = game._sighting_spider
	if mini == null or not mini._visual_is_literock:
		printerr("Literock review: licensed spider unavailable")
		quit(2)
		return
	for frame in 20: await process_frame
	mini.set_physics_process(false)
	mini.global_position = Vector3(1.55, 0.44, -1.72)
	mini.rotation.y = PI
	var door: Node3D = game.get_node("SouthEntryDoor")
	if not door.opened: door.toggle()
	await create_timer(0.72).timeout
	game.player.global_position = Vector3(-1.35, 0.44, -2.0)
	game.player.set_view(-1.47)
	game.player._pitch = -0.37
	game.player.arm.spring_length = 0.10
	game.player.visual.hide()
	for frame in 8: await process_frame
	if not await _capture("spider-literock-doorway.png"):
		quit(5)
		return
	game.player.global_position = Vector3(1.55, 0.44, -0.65)
	game.player.set_view(0.0)
	game.player._pitch = -0.85
	game.player.arm.spring_length = 0.10
	game.player.visual.hide()
	for frame in 15: await process_frame
	if not await _capture("spider-literock-house-ambient.png"):
		quit(3)
		return
	var fill := OmniLight3D.new()
	fill.name = "QAOnlySpiderFill"
	fill.position = Vector3(1.55, 1.28, -1.72)
	fill.light_color = Color(1.0, 0.84, 0.70)
	fill.light_energy = 0.55
	fill.omni_range = 2.8
	fill.shadow_enabled = false
	game.add_child(fill)
	for frame in 8: await process_frame
	if not await _capture("spider-literock-house-fill.png"):
		quit(4)
		return
	mini._play_visual("attack")
	await create_timer(0.11).timeout
	if not await _capture("spider-literock-bite.png"):
		quit(6)
		return
	mini._play_visual("idle")
	fill.hide()
	mini.hide()
	var hidden := await _sample("hidden")
	mini.show()
	var shown := await _sample("visible")
	mini.hide()
	var hidden_again := await _sample("hidden_again")
	print("LITEROCK_FRAME_PROBE ", JSON.stringify({"hidden": hidden, "visible": shown,
		"hidden_again": hidden_again,
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))}))
	quit(0)

func _sample(phase: String) -> Dictionary:
	for frame in 20: await process_frame
	var milliseconds: Array[float] = []
	var calls: Array[int] = []
	var previous := Time.get_ticks_usec()
	for frame in 90:
		await process_frame
		var current := Time.get_ticks_usec()
		milliseconds.append(float(current - previous) / 1000.0)
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		previous = current
	milliseconds.sort()
	calls.sort()
	return {"phase": phase, "median_ms": milliseconds[45], "p95_ms": milliseconds[85],
		"median_draw_calls": calls[45], "samples": milliseconds.size()}

func _capture(filename: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename)
	var result := root.get_texture().get_image().save_png(path)
	print("LITEROCK_CAPTURE ", path, " code=", result)
	return result == OK
