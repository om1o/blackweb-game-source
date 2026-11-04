extends SceneTree
## Native-rendered review of the radial, hanging, and expanded furniture webs.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Web review: house failed to load")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(40): await process_frame
	game.player._pitch = -0.24
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var entry_target := ProjectSettings.globalize_path("res://").path_join("../Evidence/web-expansion-room-entry.png")
	var entry_error := root.get_texture().get_image().save_png(entry_target)
	print("WEB_EXPANSION_CAPTURE ", entry_target, " code=", entry_error)
	if entry_error != OK:
		quit(2)
		return
	var views := [
		{"name": "web-expansion-radial-entry.png", "position": Vector3(-2.87, 0.44, -1.08), "yaw": 0.0, "pitch": 0.33},
		{"name": "web-expansion-veil-entry.png", "position": Vector3(-3.23, 0.44, -0.92), "yaw": 0.0, "pitch": 0.36},
		{"name": "web-expansion-radial-deep.png", "position": Vector3(8.82, 0.44, 0.68), "yaw": PI, "pitch": 0.35},
		{"name": "web-expansion-wraps.png", "position": Vector3(-4.02, 0.44, -1.50), "yaw": 0.12, "pitch": -0.04},
		{"name": "residue-blood-entry.png", "position": Vector3(-4.28, 0.44, -1.26), "yaw": 0.0, "pitch": -0.05},
		{"name": "residue-goo-deep.png", "position": Vector3(7.78, 0.44, 1.15), "yaw": PI, "pitch": 0.10},
		{"name": "residue-blood-deep.png", "position": Vector3(8.75, 0.44, -0.68), "yaw": 0.0, "pitch": -0.17},
	]
	for view in views:
		game.player.global_position = view.position
		game.player.set_view(view.yaw)
		game.player._pitch = view.pitch
		game.player.arm.spring_length = 0.10
		game.player.visual.hide()
		for frame in range(9): await process_frame
		await RenderingServer.frame_post_draw
		var target := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + view.name)
		var error := root.get_texture().get_image().save_png(target)
		print("WEB_EXPANSION_CAPTURE ", target, " code=", error)
		if error != OK:
			quit(2)
			return
	quit(0)
