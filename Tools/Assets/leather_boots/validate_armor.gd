extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print(("PASS " if value else "FAIL ")+label)
func _run() -> void:
	var luke := load("res://scenes/luke.tscn").instantiate() as Node3D
	root.add_child(luke)
	var controller := load("res://scripts/armor_visuals.gd").new() as Node3D
	root.add_child(controller)
	var ok: bool = controller.setup(luke)
	check(ok, "four garments bind to the existing Luke skeleton")
	if ok:
		check(controller._garments.size() == 4, "four named garment meshes")
		var skeleton: Skeleton3D = controller._skeleton
		for slot in controller._garments:
			var garment: MeshInstance3D = controller._garments[slot]
			var bounds := garment.mesh.get_aabb()
			print("BOUNDS ", slot, " ", bounds)
			check(bounds.size.length() < 2.5 and bounds.position.y > -.02 and bounds.end.y < 1.95, str(slot)+" fitted metre scale")
			var valid := true
			for bind in garment.skin.get_bind_count():
				valid = valid and skeleton.find_bone(garment.skin.get_bind_name(bind)) >= 0
			check(valid, str(slot)+" all skin names match Luke")
			check(garment.mesh.surface_get_material(0) is ShaderMaterial, str(slot)+" leather PBR material")
		var slots := [&"shirt",&"pants",&"hood",&"shoes"]
		var ids := [&"leather_shirt",&"leather_pants",&"leather_hood",&"leather_shoes"]
		var body_original: Mesh = controller._body.mesh
		for mask in 16:
			var state := {}
			for i in 4: state[slots[i]] = ids[i] if (mask & (1 << i)) != 0 else &""
			controller.apply_state(state)
			var consistent := true
			for i in 4: consistent = consistent and controller.visual_state()[slots[i]] == ((mask & (1 << i)) != 0)
			check(consistent and controller._body.mesh.get_surface_count() > 0, "equip mask %d preserves visible body and expected garments" % mask)
		controller.apply_state({})
		check(controller._body.mesh == body_original, "unequip restores original body mesh resource")
		controller.apply_state({&"pants":&"leather_pants"})
		var pants_indices: PackedInt32Array = controller._body.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var original_indices: PackedInt32Array = body_original.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var rest_points: PackedVector3Array = controller._body_rest_points[0]
		var hands_preserved := true
		for index in original_indices:
			if absf(rest_points[index].x) > 0.55 and rest_points[index].y < 1.10:
				hands_preserved = hands_preserved and pants_indices.has(index)
		check(hands_preserved, "pants coverage preserves the low A-pose palms")
		controller.apply_state({&"shirt":&"leather_shirt",&"pants":&"leather_pants",&"hood":&"leather_hood",&"shoes":&"leather_shoes"})
		var full_indices: PackedInt32Array = controller._body.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var full_triangles := {}
		for offset in range(0,full_indices.size(),3):
			full_triangles[Vector3i(full_indices[offset],full_indices[offset+1],full_indices[offset+2])] = true
		var skin_hands: PackedFloat32Array = controller._body_hand_weights[0]
		var preserved_skin := true
		var skin_count := 0
		for offset in range(0,original_indices.size(),3):
			var triangle := Vector3i(original_indices[offset],original_indices[offset+1],original_indices[offset+2])
			if (skin_hands[triangle.x]+skin_hands[triangle.y]+skin_hands[triangle.z])/3.0 >= .5:
				skin_count += 1
				preserved_skin = preserved_skin and full_triangles.has(triangle)
		check(skin_count > 100 and preserved_skin, "full armor preserves every authored hand-skin triangle")
		check(controller._pants_boot_cut.get_faces().size() < controller._pants_full.get_faces().size(), "pants inside boot shafts use reduced geometry")
		check(skeleton.get_bone_count() == 81, "existing Luke skeleton remains 81 bones")
	print("ARMOR_VALIDATION ", checks-failures.size(), "/", checks, " ", failures)
	var file := FileAccess.open("D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/armor-model-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":checks-failures.size(),"failures":failures},"  "))
	file.close()
	controller.queue_free()
	luke.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
