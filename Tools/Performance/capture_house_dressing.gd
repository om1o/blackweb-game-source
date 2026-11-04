extends SceneTree
## Native-rendered review of the new web cards and one CC0 cabinet in the real house.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("House failed to load for dressing capture")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(50): await process_frame
	game.player._pitch = -0.24
	for frame in range(5): await process_frame
	if not await _capture("res://../Evidence/house-dressing-entry.png"):
		quit(2)
		return
	# Review the cabinet/web corner from a close camera without Luke masking it.
	game.player.global_position = Vector3(-4.02, 0.44, -1.56)
	game.player.set_view(0.12)
	game.player._pitch = -0.08
	game.player.arm.spring_length = 0.10
	game.player.visual.hide()
	for frame in range(8): await process_frame
	if not await _capture("res://../Evidence/house-dressing-cabinet.png"):
		quit(3)
		return
	await _review_view(game, Vector3(-1.90, 0.44, -1.62), 0.0, 0.05)
	if not await _capture("res://../Evidence/house-dressing-shelf.png"):
		quit(4)
		return
	await _review_view(game, Vector3(-0.04, 0.44, 2.48), -0.11, 0.36)
	if not await _capture("res://../Evidence/house-dressing-caged-light.png"):
		quit(5)
		return
	await _review_view(game, Vector3(7.86, 0.44, -0.38), 0.0, 0.38)
	if not await _capture("res://../Evidence/house-dressing-ceiling-sheet.png"):
		quit(6)
		return
	await _review_view(game, Vector3(11.59, 0.44, 0.27), PI, 0.38)
	if not await _capture("res://../Evidence/house-dressing-deep-sheet.png"):
		quit(7)
		return
	quit(0)


func _review_view(game: Node3D, position: Vector3, yaw: float, pitch: float) -> void:
	game.player.global_position = position
	game.player.set_view(yaw)
	game.player._pitch = pitch
	game.player.arm.spring_length = 0.10
	game.player.visual.hide()
	for frame in range(8): await process_frame


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(path)
	print("DRESSING_CAPTURE ", path, " code=", result)
	return result == OK
