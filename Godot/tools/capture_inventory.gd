extends SceneTree
## Native visual QA of the 50-slot inventory using the actual house HUD.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Inventory capture: house did not load")
		quit(1)
		return
	game._resume()
	game._toggle_inventory()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../Evidence/phase1-minimal-inventory.png"
	var code := root.get_texture().get_image().save_png(path)
	print("INVENTORY_CAPTURE ", path, " code=", code)
	quit(0 if code == OK else 2)
