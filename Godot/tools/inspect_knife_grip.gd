extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	game.player.select_quick_slot(1)
	for frame in range(30): await physics_frame
	var player = game.player
	print("KNIFE_LOCAL_ROTATION ", player._hand_knife.quaternion)
	print("KNIFE_LOCAL_POSITION ", player._hand_knife.position)
	var rig: Skeleton3D = player._luke_skeleton
	for bone_name in ["Bip01 R Hand", "Bip01 R Finger0", "Bip01 R Finger01", "Bip01 R Finger1", "Bip01 R Finger12", "Bip01 R Finger2", "Bip01 R Finger22", "Bip01 R Finger3", "Bip01 R Finger32", "Bip01 R Finger4", "Bip01 R Finger42"]:
		var world: Vector3 = rig.to_global(rig.get_bone_global_pose(rig.find_bone(bone_name)).origin)
		print(bone_name, " HAND_LOCAL ", player._hand_mount.to_local(world))
	quit()
