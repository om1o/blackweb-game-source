extends SceneTree
## Native-rendered visual QA for the four user-selectable status HUD layouts.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("House failed to load for HUD capture")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(45): await process_frame
	var names := ["field", "survival", "minimal", "vertical"]
	for index in range(4):
		game._set_hud_layout(index)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://../Evidence/phase1-hud-%s.png" % names[index]
		var code := root.get_texture().get_image().save_png(path)
		if code != OK:
			printerr("HUD capture failed: ", path, " code=", code)
			quit(2)
			return
		print("HUD_CAPTURE ", path)
	quit(0)
