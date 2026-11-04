extends SceneTree
## Rendered check of both opening storage fixtures from Luke's shoulder camera.

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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for fixture in get_nodes_in_group("storage"):
		var label: String = "drawer" if fixture.storage_kind == &"drawer" else "cabinet"
		game.player.global_position = Vector3(fixture.global_position.x, 0.44, fixture.global_position.z - 1.2)
		game.player.velocity = Vector3.ZERO
		for frame in range(25):
			var direction: Vector3 = (fixture.global_position - game.player.camera.global_position).normalized()
			game.player._pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -1.05, 0.65)
			game.player.set_view(atan2(-direction.x, -direction.z))
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../Evidence/phase1-%s-closed.png" % label)
		fixture.interact()
		await create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../Evidence/phase1-%s-open.png" % label)
		print("STORAGE_CAPTURE ", label)
	quit(0)
