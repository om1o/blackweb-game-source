extends SceneTree
## Run with a native renderer: Godot --path <Godot project> --script res://tools/capture_item_poses.gd
## Captures three rendered poses without modifying saves or progression.

var game: Node3D
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		push_error("House did not load for item pose capture")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(45): await physics_frame
	await _capture("held-flashlight.png", "Starter flashlight aimed in Luke's hand")
	game.player.use_item(&"knife")
	for frame in range(17): await physics_frame
	await _capture("knife-mid-stab.png", "Worn knife during timed stab")
	for frame in range(35): await physics_frame
	game.player.health = 60.0
	game.player.health_changed.emit(60.0)
	game.player.use_item(&"candy_bar")
	for frame in range(38): await physics_frame
	await _capture("candy-mid-eat.png", "Candy bar raised toward Luke's mouth before healing")
	var file := FileAccess.open("res://data/item_pose_capture.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"kind": "native rendered starter item pose capture", "results": results}, "  "))
		file.close()
	print("Item pose captures: ", results.size())
	quit(0 if results.size() == 3 and results.all(func(row): return row.saved) else 1)

func _capture(filename: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename)
	var error := root.get_texture().get_image().save_png(path)
	var player = game.player
	var hand: Node3D = player._hand_mount
	var prop: Node3D = player._hand_flashlight if player._action_kind == &"" else (player._hand_knife if player._action_kind == &"knife" else player._hand_candy)
	var rig: Skeleton3D = player._luke_skeleton
	var head_index := rig.find_bone("Bip01 Head")
	var head_world: Vector3 = rig.to_global(rig.get_bone_global_pose(head_index).origin) if head_index >= 0 else Vector3.ZERO
	var blade_direction: Vector3 = prop.global_basis * Vector3(0, 0, -1)
	results.append({"label": label, "path": path, "saved": error == OK, "action": str(player._action_kind), "hand_world": hand.global_position, "hand_screen": player.camera.unproject_position(hand.global_position), "prop_world": prop.global_position, "prop_screen": player.camera.unproject_position(prop.global_position), "head_world": head_world, "head_screen": player.camera.unproject_position(head_world), "prop_direction": blade_direction, "camera_forward": -player.camera.global_basis.z, "prop_tip_screen": player.camera.unproject_position(prop.global_position + blade_direction * 0.28)})
