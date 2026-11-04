extends SceneTree
## Prints source mesh bounds before mounting the CC0 weathered fish knife.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model = load("res://assets/third_party/poly_haven/fish_knife/fish_knife_1k.gltf").instantiate()
	root.add_child(model)
	await process_frame
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var node := mesh as MeshInstance3D
		print(node.name, " position=", node.global_position, " bounds=", node.mesh.get_aabb(), " global_bounds=", node.get_aabb() * node.global_transform)
	quit()
