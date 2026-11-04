extends SceneTree
## Native gameplay-distance and QA close-up views of the worn knife grip.
## The gameplay camera and item pose are not changed in project code.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		push_error("House did not load for knife close-up")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(45): await physics_frame
	var player = game.player
	var knife: Node3D = player._hand_knife
	player.select_quick_slot(1)
	for frame in range(15): await physics_frame
	await _capture("knife-ready-gameplay.png")
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.near = 0.04
	root.add_child(camera)
	game.status_hud.hide()
	var fill := OmniLight3D.new()
	fill.name = "QAKnifeTextureFill"
	fill.light_energy = 1.0
	fill.omni_range = 0.8
	fill.shadow_enabled = false
	root.add_child(fill)
	await _capture_close(knife, camera, fill, "knife-grip-ready-qa.png")
	fill.visible = false
	game.status_hud.show()
	player.camera.current = true
	player.use_item(&"knife")
	for frame in range(17): await physics_frame
	await _capture("knife-stab-gameplay.png")
	game.status_hud.hide()
	await _capture_close(knife, camera, fill, "knife-grip-close-qa.png")
	quit()

func _capture_close(knife: Node3D, camera: Camera3D, fill: OmniLight3D, filename: String) -> void:
	var direction := -knife.global_basis.z.normalized()
	var side := direction.cross(Vector3.UP).normalized()
	camera.global_position = knife.global_position - direction * 0.12 + side * 0.46 + Vector3.UP * 0.09
	camera.look_at(knife.global_position + direction * 0.09, Vector3.UP)
	camera.current = true
	fill.visible = true
	fill.global_position = knife.global_position + side * 0.18 + Vector3.UP * 0.14
	await _capture(filename)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename)
	var error := root.get_texture().get_image().save_png(path)
	print("Knife capture: ", path, " saved=", error == OK)
