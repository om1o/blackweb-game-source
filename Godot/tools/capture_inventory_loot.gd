extends SceneTree
## Native proof that found supplies enter the actual 50-cell backpack.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		quit(1)
		return
	game._resume()
	for pickup in game._supply_pickups:
		pickup.interact()
	game._toggle_inventory()
	for index in range(game.player.inventory.slots.size()):
		if game.player.inventory.item_at(index) == &"battery_35":
			game.status_hud._select_cell(index)
			break
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../Evidence/inventory-50-loot.png"
	var code := root.get_texture().get_image().save_png(path)
	print("INVENTORY_LOOT_CAPTURE ", path, " code=", code)
	quit(0 if code == OK else 2)
