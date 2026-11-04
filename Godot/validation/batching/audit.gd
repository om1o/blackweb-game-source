extends SceneTree
const Batcher = preload("res://scripts/house_batching.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var house: Node3D = load("res://scenes/recovered_house.tscn").instantiate()
	root.add_child(house)
	var originals: Array = house.find_children("*", "MeshInstance3D", true, false)
	var collision_before: int = house.find_children("*", "CollisionShape3D", true, false).size()
	var hinge := Node3D.new()
	hinge.name = "FrontDoorHinge"
	house.add_child(hinge)
	for holder in house.get_children():
		if not holder is Node3D or not holder.has_meta("ue_mesh_path"): continue
		if str(holder.get_meta("ue_component_name", "")).contains("BP_Door_01_C_2"):
			holder.reparent(hinge, true)
			continue
		var source: String = str(holder.get_meta("ue_mesh_path"))
		var structural: bool = source.contains("/Mesh_Wall_") or source.contains("/Mesh_Floor_")
		for child in holder.find_children("*", "MeshInstance3D", true, false):
			if source.contains("/OldBrickHouse/") and not structural: child.visibility_range_end = 24.0
	var stats: Dictionary = Batcher.new().apply(house)
	stats["canonical_instances_retained"] = originals.all(func(node): return is_instance_valid(node) and node.is_inside_tree())
	stats["collision_count_before"] = collision_before
	stats["collision_count_after"] = house.find_children("*", "CollisionShape3D", true, false).size()
	stats["parent_visibility_verified"] = true
	for batch in house.get_children():
		if not batch is MultiMeshInstance3D: continue
		var count_before: int = batch.multimesh.visible_instance_count
		var parent: Node3D = batch.source_parents[0]
		parent.hide()
		var count_hidden: int = batch.multimesh.visible_instance_count
		parent.show()
		if count_hidden >= count_before or batch.multimesh.visible_instance_count != count_before: stats["parent_visibility_verified"] = false
		break
	var report := FileAccess.open("res://validation/batching/report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(stats, "\t"))
	report.close()
	var compact: Dictionary = stats.duplicate()
	compact.erase("groups")
	print(JSON.stringify(compact))
	quit(0 if stats["transform_equivalence_verified"] and stats["material_equivalence_verified"] and stats["parent_visibility_verified"] and stats["canonical_instances_retained"] and stats["collision_count_before"] == stats["collision_count_after"] else 1)
