extends SceneTree
## Native render of the trial's title menu for visual review.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Menu capture: house did not load")
		quit(1)
		return
	for frame in range(16): await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/blackweb-main-menu.png")
	var code := root.get_texture().get_image().save_png(path)
	print("MENU_CAPTURE ", path, " code=", code)
	quit(0 if code == OK else 2)
