extends SceneTree
## Native inspection of the production house/materials, without extra lights.
var game: Node
var prefix := "environment-v3"
var output_directory := "res://../Evidence"

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty(): prefix = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1: output_directory = OS.get_cmdline_user_args()[1]
	call_deferred("_run")

func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		push_error("Cannot create capture output directory: " + output_directory)
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	for enemy in get_nodes_in_group("mini_spider"): enemy.set_physics_process(false)
	for frame in range(30): await process_frame
	var shots := [
		["entry", Vector3(-2.8, 0.44, 0.8), Vector3(-4.2, 1.8, -3.25)],
		["supply", Vector3(1.8, 0.44, -1.1), Vector3(1.0, 1.7, -3.2)],
		["records", Vector3(0.8, 0.44, 1.2), Vector3(1.85, 1.6, 3.3)],
		["spider", Vector3(5.6, 0.44, -1.35), Vector3(4.75, 2.0, -3.60)],
		["vault", Vector3(4.6, 0.44, 0.95), Vector3(5.8, 2.0, 3.43)],
	]
	var results := []
	for shot in shots:
		game.player.global_position = shot[1]
		game.player.velocity = Vector3.ZERO
		for frame in range(28):
			var direction: Vector3 = (shot[2] - game.player.camera.global_position).normalized()
			game.player._pitch = clampf(asin(direction.y), -1.05, 0.65)
			game.player.set_view(atan2(-direction.x, -direction.z))
			game.player.pivot.rotation.x = game.player._pitch
			game.player._update_right_arm_pose(1.0)
			game.player._update_held_item_visuals(true, 1.0)
			game.player._tick_equipment(0.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var target := output_directory.path_join(prefix + "-" + str(shot[0]) + ".png")
		var result := image.save_png(target)
		results.append({"room": shot[0], "saved": result == OK, "size": [image.get_width(), image.get_height()]})
		print("ENVIRONMENT_CAPTURE ", shot[0], " saved=", result == OK)
	_stop_audio(game)
	game.queue_free()
	for frame in range(3): await process_frame
	await create_timer(0.12).timeout
	var report := FileAccess.open(output_directory.path_join(prefix + "-captures.json"), FileAccess.WRITE)
	if report == null:
		push_error("Cannot save capture report: " + output_directory)
		quit(1)
		return
	report.store_string(JSON.stringify({"native": true, "production_lighting": true,
		"limits": "Posed native visual inspection; AI frozen for repeatability. Not a human playtest or performance measurement.", "shots": results}, "  "))
	quit(0 if results.all(func(row): return row.saved) else 1)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)
