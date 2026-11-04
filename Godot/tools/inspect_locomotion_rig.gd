extends SceneTree
## Read-only inspection of recovered Luke leg/spine bones and available clips.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var luke = load("res://scenes/luke.tscn").instantiate()
	root.add_child(luke)
	await process_frame
	var skeleton: Skeleton3D = luke.find_children("*", "Skeleton3D", true, false)[0]
	for index in range(skeleton.get_bone_count()):
		var name := skeleton.get_bone_name(index)
		if index < 10 or "Thigh" in name or "Calf" in name or "Foot" in name or "Toe" in name:
			print(index, " ", name, " parent=", skeleton.get_bone_parent(index), " local=", skeleton.get_bone_pose_position(index), " rest=", skeleton.get_bone_rest(index).origin)
	var animation: AnimationPlayer = luke.find_children("*", "AnimationPlayer", true, false)[0]
	print("clips=", animation.get_animation_list())
	quit()
