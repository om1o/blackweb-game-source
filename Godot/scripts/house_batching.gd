extends RefCounted
## Conservative runtime batching of immutable recovered house geometry.
## Call AFTER door reparenting and original-geometry occluder construction.
## Does not replace canonical nodes, collision, geometry or texture resources.

const CELL_SIZE := 6.0
const RENDER_PROPERTIES := ["layers", "cast_shadow", "gi_mode", "extra_cull_margin", "ignore_occlusion_culling", "sorting_offset", "sorting_use_aabb_center", "lod_bias"]
const NONVISUAL_MATERIAL_PROPERTIES := ["resource_local_to_scene", "resource_path", "resource_scene_unique_id"]


class VisibleBatch extends MultiMeshInstance3D:
	var source_parents: Array[Node3D] = []
	var source_transforms: Array[Transform3D] = []

	func observe(parents: Array[Node3D], transforms: Array[Transform3D], house: Node3D) -> void:
		source_parents = parents
		source_transforms = transforms
		var watched: Dictionary = {}
		for parent in parents:
			var ancestor: Node = parent
			while ancestor != null and ancestor != house:
				if ancestor is Node3D and not watched.has(ancestor.get_instance_id()):
					watched[ancestor.get_instance_id()] = true
					ancestor.visibility_changed.connect(_sync_visibility)
				ancestor = ancestor.get_parent()
		_sync_visibility()

	func _sync_visibility() -> void:
		# Compact visible transforms instead of zero-scale transforms, preserving
		# valid normal matrices. No per-frame polling or custom shader is needed.
		var visible_count := 0
		for index in range(source_parents.size()):
			var parent: Node3D = source_parents[index]
			if is_instance_valid(parent) and parent.is_visible_in_tree():
				multimesh.set_instance_transform(visible_count, source_transforms[index])
				visible_count += 1
		multimesh.visible_instance_count = visible_count


func apply(house: Node3D) -> Dictionary:
	if house == null or not house.is_inside_tree():
		return {"applied": false, "reason": "House must be an instantiated Node3D in the scene tree."}
	if house.has_meta("blackweb_static_batching"):
		return house.get_meta("blackweb_static_batching")
	var stats := {"applied": false, "cell_size_m": CELL_SIZE, "source_mesh_instances": 0, "eligible_instances": 0, "batched_instances": 0, "batch_count": 0, "cloned_mesh_count": 0, "source_surface_submissions": 0, "batch_surface_submissions": 0, "estimated_submission_reduction": 0, "transform_equivalence_verified": true, "material_equivalence_verified": true, "skipped": {}, "groups": [], "policy": "Exact shared ArrayMesh + complete stored StandardMaterial3D properties/texture paths + render state, positive transforms, 6m spatial cells. Opaque static recovered nodes only. Estimates precede camera/occlusion culling and render passes."}
	var backend_readback: bool = DisplayServer.get_name() != "headless"
	stats["backend_transform_readback"] = "required before hiding originals" if backend_readback else "unsupported by headless dummy backend; CPU world-transform equivalence checked"
	var groups: Dictionary = {}
	var signatures: Dictionary = {}
	var pending: Array[Node] = [house]
	var house_inverse := house.global_transform.affine_inverse()
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is MeshInstance3D:
			continue
		var source := node as MeshInstance3D
		stats["source_mesh_instances"] += 1
		var reason: String = _exclude(source, house)
		if not reason.is_empty():
			_skip(stats, reason)
			continue
		var local_transform: Transform3D = house_inverse * source.global_transform
		if not local_transform.is_finite() or local_transform.basis.determinant() <= 0.000001:
			_skip(stats, "invalid_or_reflected_transform")
			continue
		# Keep normal transforms exact without relying on instancing support for
		# nonuniform/sheared normal matrices in a particular renderer backend.
		if not _uniform_orthogonal(local_transform.basis):
			_skip(stats, "nonuniform_or_sheared_basis")
			continue
		var material_keys: Array[String] = []
		var materials: Array[StandardMaterial3D] = []
		for surface in range(source.mesh.get_surface_count()):
			var material: Material = source.get_active_material(surface)
			if not material is StandardMaterial3D:
				reason = "custom_or_null_material"
				break
			var standard := material as StandardMaterial3D
			if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or standard.next_pass != null or standard.get_script() != null or standard.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or standard.proximity_fade_enabled or standard.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
				reason = "transparent_or_dynamic_material"
				break
			var identity: int = standard.get_instance_id()
			if not signatures.has(identity):
				signatures[identity] = _material_key(standard)
			var key: String = signatures[identity]
			if key.is_empty():
				reason = "unsupported_material_property"
				break
			material_keys.append(key)
			materials.append(standard)
		if not reason.is_empty():
			_skip(stats, reason)
			continue
		var center: Vector3 = local_transform * source.mesh.get_aabb().get_center()
		var cell := Vector3i(floori(center.x / CELL_SIZE), floori(center.y / CELL_SIZE), floori(center.z / CELL_SIZE))
		var render_values: Array = []
		for property in RENDER_PROPERTIES:
			render_values.append([property, source.get(property)])
		var mesh_key: String = str(source.mesh.get_instance_id()) + ":" + "|".join(material_keys)
		var group_key: String = mesh_key + ":" + var_to_bytes(render_values).hex_encode() + ":" + str(cell)
		if not groups.has(group_key):
			groups[group_key] = {"mesh_key": mesh_key, "mesh": source.mesh, "materials": materials, "members": [], "transforms": [], "render": render_values, "cell": cell}
		groups[group_key]["members"].append(source)
		groups[group_key]["transforms"].append(local_transform)
		stats["eligible_instances"] += 1

	var mesh_copies: Dictionary = {}
	for group in groups.values():
		var members: Array = group["members"]
		if members.size() < 2:
			_skip(stats, "singleton_cell")
			continue
		var mesh_key: String = group["mesh_key"]
		if not mesh_copies.has(mesh_key):
			var copy: ArrayMesh = (group["mesh"] as ArrayMesh).duplicate(false) as ArrayMesh
			for surface in range(copy.get_surface_count()):
				copy.surface_set_material(surface, group["materials"][surface])
			mesh_copies[mesh_key] = copy
		var batched_mesh: ArrayMesh = mesh_copies[mesh_key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = batched_mesh
		multimesh.instance_count = members.size()
		var bounds: AABB
		var has_bounds := false
		var transforms: Array[Transform3D] = []
		var parents: Array[Node3D] = []
		var paths: Array[String] = []
		var valid := true
		for index in range(members.size()):
			var transform: Transform3D = group["transforms"][index]
			transforms.append(transform)
			multimesh.set_instance_transform(index, transform)
			if not (house.global_transform * transform).is_equal_approx(members[index].global_transform):
				valid = false
			if backend_readback and not multimesh.get_instance_transform(index).is_equal_approx(transform):
				valid = false
			var instance_bounds: AABB = transform * batched_mesh.get_aabb()
			bounds = bounds.merge(instance_bounds) if has_bounds else instance_bounds
			has_bounds = true
			parents.append(members[index].get_parent() as Node3D)
			paths.append(str(house.get_path_to(members[index])))
		if not valid:
			stats["transform_equivalence_verified"] = false
			_skip(stats, "transform_verification_failed")
			continue
		for surface in range(batched_mesh.get_surface_count()):
			# Per-component source overrides are distinct Resource objects. Compare
			# their complete visual signatures, not their resource identities.
			var copied_material: Material = batched_mesh.surface_get_material(surface)
			if not copied_material is StandardMaterial3D or _material_key(copied_material) != _material_key(group["materials"][surface]):
				valid = false
		if not valid:
			stats["material_equivalence_verified"] = false
			_skip(stats, "material_verification_failed")
			continue
		multimesh.custom_aabb = bounds
		var batch := VisibleBatch.new()
		batch.name = "StaticCellBatch_%03d" % int(stats["batch_count"])
		batch.multimesh = multimesh
		for property in group["render"]:
			batch.set(property[0], property[1])
		batch.set_meta("source_node_paths", paths)
		batch.set_meta("source_mesh_resource", group["mesh"].resource_path)
		batch.set_meta("static_recovered_batch", true)
		house.add_child(batch)
		batch.observe(parents, transforms, house)
		for member in members:
			member.set_meta("blackweb_batch_path", str(house.get_path_to(batch)))
			member.set_meta("blackweb_original_visible", member.visible)
			member.visible = false
		var surface_count: int = batched_mesh.get_surface_count()
		stats["batched_instances"] += members.size()
		stats["batch_count"] += 1
		stats["source_surface_submissions"] += members.size() * surface_count
		stats["batch_surface_submissions"] += surface_count
		stats["groups"].append({"batch": str(batch.name), "mesh": batched_mesh.resource_name, "source_mesh": group["mesh"].resource_path, "cell": [group["cell"].x, group["cell"].y, group["cell"].z], "instances": members.size(), "surfaces": surface_count, "visible_instances": multimesh.visible_instance_count})
	stats["cloned_mesh_count"] = mesh_copies.size()
	stats["estimated_submission_reduction"] = stats["source_surface_submissions"] - stats["batch_surface_submissions"]
	stats["applied"] = stats["batch_count"] > 0
	house.set_meta("blackweb_static_batching", stats)
	return stats


func _exclude(source: MeshInstance3D, house: Node3D) -> String:
	if not source.mesh is ArrayMesh or source.mesh.get_surface_count() == 0:
		return "unsupported_mesh"
	if not source.is_visible_in_tree() or not source.get_parent() is Node3D:
		return "hidden_or_unsupported_parent"
	if source.skin != null or source.mesh.get_blend_shape_count() > 0:
		return "animated_mesh"
	if source.material_overlay != null or source.transparency != 0.0:
		return "overlay_or_instance_transparency"
	if source.visibility_range_begin != 0.0 or source.visibility_range_end != 0.0 or not source.visibility_parent.is_empty():
		return "per_instance_visibility_range"
	for property in source.get_property_list():
		if str(property["name"]).begins_with("instance_shader_parameters/") and source.get(property["name"]) != null:
			return "instance_shader_parameter"
	var ancestor: Node = source
	var recovered := false
	while ancestor != null and ancestor != house:
		if ancestor.get_script() != null or ancestor is AnimationPlayer or ancestor is AnimationTree or ancestor is CharacterBody3D or ancestor is RigidBody3D:
			return "scripted_or_dynamic_ancestry"
		var label: String = (str(ancestor.name) + " " + str(ancestor.get_meta("ue_mesh_path", "")) + " " + str(ancestor.get_meta("ue_component_name", ""))).to_lower()
		if label.contains("door") or label.contains("hinge") or label.contains("interact") or label.contains("pickup") or label.contains("exteriorinteraction"):
			return "door_or_interaction"
		if ancestor.has_meta("ue_mesh_path"):
			recovered = true
		ancestor = ancestor.get_parent()
	if not recovered or ancestor != house:
		return "not_canonical_recovered_geometry"
	if source.global_transform.basis.determinant() <= 0.000001:
		return "reflected_or_degenerate_transform"
	return ""


func _material_key(material: StandardMaterial3D) -> String:
	var names: Array[String] = []
	for property in material.get_property_list():
		var name: String = str(property["name"])
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE and not NONVISUAL_MATERIAL_PROPERTIES.has(name):
			names.append(name)
	names.sort()
	var values: Array = []
	for name in names:
		var value: Variant = material.get(name)
		if value is Resource:
			# Exported textures are immutable and shared. A generated/pathless
			# resource is conservatively incompatible, even if it looks similar.
			if not value is Texture2D or value.resource_path.is_empty():
				return ""
			values.append([name, "Texture2D", value.resource_path])
		elif typeof(value) == TYPE_OBJECT or typeof(value) == TYPE_CALLABLE or typeof(value) == TYPE_SIGNAL or typeof(value) == TYPE_RID:
			if value != null:
				return ""
			values.append([name, null])
		else:
			values.append([name, value])
	return var_to_bytes(values).hex_encode().sha256_text()


func _uniform_orthogonal(basis: Basis) -> bool:
	var lengths := Vector3(basis.x.length(), basis.y.length(), basis.z.length())
	if lengths.x <= 0.000001 or not is_equal_approx(lengths.x, lengths.y) or not is_equal_approx(lengths.x, lengths.z):
		return false
	var x: Vector3 = basis.x / lengths.x
	var y: Vector3 = basis.y / lengths.y
	var z: Vector3 = basis.z / lengths.z
	return absf(x.dot(y)) < 0.00001 and absf(x.dot(z)) < 0.00001 and absf(y.dot(z)) < 0.00001


func _skip(stats: Dictionary, reason: String) -> void:
	stats["skipped"][reason] = int(stats["skipped"].get(reason, 0)) + 1
