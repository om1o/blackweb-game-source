extends SceneTree
## Rig inspection aid; prints recovered Luke skeleton arm chain and pose APIs.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var luke = load("res://scenes/luke.tscn").instantiate()
	root.add_child(luke)
	await process_frame
	var skeletons = luke.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		print("NO SKELETON")
		quit(1)
		return
	var skeleton := skeletons[0] as Skeleton3D
	for method in skeleton.get_method_list():
		if "bone" in str(method.name) and ("pose" in str(method.name) or "override" in str(method.name)):
			print("METHOD ", method.name)
	for index in range(skeleton.get_bone_count()):
		var name := skeleton.get_bone_name(index)
		if "R " in name or "L " in name or "Spine" in name or "Neck" in name:
			print("BONE ", index, " ", name, " parent=", skeleton.get_bone_parent(index), " rest=", skeleton.get_bone_rest(index).origin, " pose=", skeleton.get_bone_pose(index).origin, " global=", skeleton.get_bone_global_pose(index).origin)
	var animations: Array[Node] = luke.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty(): print("ANIMATIONS ", (animations[0] as AnimationPlayer).get_animation_list())
	quit(0)
