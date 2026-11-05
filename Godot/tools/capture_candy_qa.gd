extends SceneTree
## Native close-ups of the actual held candy bar and bite pose.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		push_error("House did not load for candy QA")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player = game.player
	player.select_quick_slot(2)
	for frame in range(35): await physics_frame
	_print_candy_vectors(player, "ready")
	await _save("candy-held-gameplay.png")
	var camera := Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.02
	root.add_child(camera)
	game.status_hud.hide()
	var fill := OmniLight3D.new()
	fill.light_energy = 0.8
	fill.omni_range = 0.65
	fill.shadow_enabled = false
	root.add_child(fill)
	await _capture(player, camera, fill, "candy-ready-qa.png")
	player.health = 60.0
	game.status_hud.show()
	player.camera.current = true
	player.use_selected_item()
	for frame in range(36): await physics_frame
	_print_candy_vectors(player, "eating")
	await _save("candy-bite-gameplay.png")
	game.status_hud.hide()
	await _capture(player, camera, fill, "candy-eating-qa.png")
	game.status_hud.show()
	player.camera.current = true
	for frame in range(12): await physics_frame
	await _save("candy-bitten-gameplay.png")
	game.status_hud.hide()
	await _capture(player, camera, fill, "candy-bitten-qa.png")
	quit()

func _capture(player: BlackwebPlayer, camera: Camera3D, fill: OmniLight3D, filename: String) -> void:
	var candy: Node3D = player._hand_candy
	var camera_back: Vector3 = player.camera.global_basis.z.normalized()
	var camera_right: Vector3 = player.camera.global_basis.x.normalized()
	camera.global_position = candy.global_position + camera_back * 0.32 + camera_right * 0.10 + Vector3.UP * 0.025
	camera.look_at(candy.global_position + Vector3.UP * 0.035, Vector3.UP)
	camera.current = true
	fill.global_position = candy.global_position + camera_back * 0.20 + Vector3.UP * 0.09
	await _save(filename)

func _save(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename)
	var error := root.get_texture().get_image().save_png(path)
	print("Candy QA: ", path, " saved=", error == OK)

func _print_candy_vectors(player: BlackwebPlayer, label: String) -> void:
	var bar: Node3D = player._hand_candy
	var hand: Node3D = player._hand_mount
	var tip := bar.to_global(Vector3(0.104, 0.0, 0.0))
	var wrapper := bar.to_global(Vector3(-0.012, 0.0, 0.0))
	print("Candy QA ", label, " hand=", hand.global_position, " wrapper=", wrapper, " tip=", tip,
		" hand_screen=", player.camera.unproject_position(hand.global_position),
		" wrapper_screen=", player.camera.unproject_position(wrapper),
		" tip_screen=", player.camera.unproject_position(tip))
