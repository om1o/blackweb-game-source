extends SceneTree
## Native rig diagnostic: prints the animated right-hand basis and grip positions.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	for frame in range(45): await physics_frame
	var player = game.player
	var rig: Skeleton3D = player._luke_skeleton
	for name in ["Bip01 R UpperArm", "Bip01 R Forearm"]:
		var index := rig.find_bone(name)
		print(name, " origin=", rig.to_global(rig.get_bone_global_pose(index).origin))
	for name in ["Bip01 R Hand", "Bip01 R Finger0", "Bip01 R Finger1", "Bip01 R Finger11", "Bip01 R Finger2", "Bip01 R Finger21", "Bip01 R Finger3", "Bip01 R Finger31", "Bip01 R Finger4", "Bip01 R Finger41"]:
		var index := rig.find_bone(name)
		var pose := rig.get_bone_global_pose(index)
		print(name, " origin=", rig.to_global(pose.origin), " axes=", rig.global_basis * pose.basis.x, ",", rig.global_basis * pose.basis.y, ",", rig.global_basis * pose.basis.z)
	print("torch=", player._hand_flashlight.global_position, " lens=", player._hand_flashlight.to_global(Vector3(0, 0, -0.13)), " direction=", -player._hand_flashlight.global_basis.z.normalized(), " lamp=", player.lamp.global_position, " camera=", player.camera.global_position, " camera_forward=", -player.camera.global_basis.z.normalized())
	player.health = 60.0
	player.use_item(&"candy_bar")
	for frame in range(38): await physics_frame
	print("candy hand=", player._hand_mount.global_position, " hand_axes=", player._hand_mount.global_basis.x, ",", player._hand_mount.global_basis.y, ",", player._hand_mount.global_basis.z, " candy=", player._hand_candy.global_position)
	quit()
