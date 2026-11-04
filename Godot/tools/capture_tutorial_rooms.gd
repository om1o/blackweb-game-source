extends SceneTree
## Native 1280×720 visual review of the playable five-room tutorial.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(45): await process_frame
	game.player.global_position = Vector3(-2.15, 0.44, 0.30)
	game.player.velocity = Vector3.ZERO
	game.player.set_view(-1.20)
	game.player._pitch = -0.08
	for frame in range(12): await process_frame
	if not await _capture("res://../Evidence/tutorial-entry-native.png"):
		quit(2)
		return
	# A second frame shows the rear encounter chamber after the blackout.
	game.player.global_position = Vector3(4.65, 0.44, -2.10)
	game.player.velocity = Vector3.ZERO
	game.spider.activate(game.player)
	game.spider.set_physics_process(false)
	game._power_target = 0.0
	for frame in range(130): await process_frame
	for frame in range(25):
		var toward: Vector3 = (game.spider.global_position + Vector3.UP * 0.38 - game.player.camera.global_position).normalized()
		game.player._pitch = clampf(asin(clampf(toward.y, -1.0, 1.0)), -1.05, 0.65)
		game.player.set_view(atan2(-toward.x, -toward.z))
		await process_frame
	game.spider._set_state(game.spider.State.WINDUP)
	game.spider._state_elapsed = 0.42
	game.spider._update_attack_tell()
	for frame in range(3): await process_frame
	if not await _capture("res://../Evidence/tutorial-rear-spider-native.png"):
		quit(3)
		return
	game.queue_free()
	await process_frame
	quit(0)

func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var saved := image.save_png(path)
	print("TUTORIAL_CAPTURE ", path, " size=", image.get_width(), "x", image.get_height(), " code=", saved)
	return saved == OK
