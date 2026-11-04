extends SceneTree
## Native visual check of the animated vault-facing door in its closed state.

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
	game.player.global_position = Vector3(1.55, 0.44, 2.0)
	game.player.velocity = Vector3.ZERO
	game.player.set_view(-PI * 0.5)
	game.player._pitch = -0.08
	for frame in range(24): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var result := image.save_png("res://../Evidence/tutorial-vault-door-native.png")
	print("VAULT_DOOR_CAPTURE ", result, " ", image.get_width(), "x", image.get_height())
	var vault = game.get_node_or_null("RearNorthDoor")
	if vault == null:
		quit(3)
		return
	vault.toggle()
	for frame in range(55): await process_frame
	await RenderingServer.frame_post_draw
	var open_image: Image = root.get_texture().get_image()
	var open_result := open_image.save_png("res://../Evidence/tutorial-vault-door-open-native.png")
	print("VAULT_DOOR_OPEN_CAPTURE ", open_result, " angle=", vault._hinge.rotation.y)
	var passed: bool = result == OK and open_result == OK and vault.opened and vault._hinge.rotation.y < -1.2
	game.queue_free()
	await process_frame
	quit(0 if passed else 2)
