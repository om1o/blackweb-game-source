extends SceneTree
## Native one-off studio renders, from the player's actual held/armour meshes.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Item covers require the native renderer")
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	var player = load("res://scripts/player.gd").new()
	world.add_child(player)
	player.active = false
	player.set_physics_process(false)
	player.attach_model(load("res://scenes/luke.tscn"))
	player.hide()
	var preview = load("res://scripts/item_preview.gd").new()
	root.add_child(preview)
	await process_frame
	preview._viewport.size = Vector2i(256, 256)
	preview._viewport.msaa_3d = Viewport.MSAA_4X
	var output := "res://assets/generated/item_covers"
	DirAccess.make_dir_recursive_absolute(output)
	var entries: Array[Dictionary] = []
	for id in load("res://scripts/item_covers.gd").IDS:
		var source: Node3D = player.item_preview_source(&"battery_35" if id == &"battery" else id)
		if source == null:
			push_error("Missing cover source: " + str(id))
			quit(2)
			return
		preview.show_model(source, id)
		# Product views expose the blade, wrapper face and garment fronts.
		var distance: float = preview._camera.position.length()
		if str(id).begins_with("leather_"):
			preview._camera.position = Vector3(.35,.15,-2).normalized()*distance
		elif id == &"knife":
			preview._camera.position = Vector3(.4,2,1.1).normalized()*distance
		elif id == &"candy_bar":
			preview._camera.position = Vector3(1.8,-2.2,.6).normalized()*distance
		preview._camera.look_at(Vector3.ZERO,Vector3.UP)
		var result: Array = await preview.preview_ready
		await process_frame
		var image: Image = result[0].get_image()
		var path := output + "/" + str(id) + ".png"
		if image.save_png(path) != OK:
			quit(3)
			return
		entries.append({"id": id, "source_node": str(source.name), "file": str(id) + ".png", "sha256": FileAccess.get_sha256(path), "width": image.get_width(), "height": image.get_height()})
	var manifest := FileAccess.open(output + "/provenance.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"method": "Godot studio render of the actual player item meshes", "builder": "res://tools/bake_item_covers.gd", "items": entries, "rights": "Rendered appearances retain the underlying asset attributions in Docs/ASSET_PROVENANCE.md; no source meshes are redistributed here."}, "\t"))
	print("ITEM_COVERS_BAKED ", entries.size())
	quit()
