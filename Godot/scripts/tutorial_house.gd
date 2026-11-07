class_name BlackwebTutorialHouse
extends RefCounted

## The recovered mansion stays intact on disk. At runtime the opening uses its
## ground-floor entry shell, then closes that shell with copies of its brick wall.
const MIN_X := -5.60
const MAX_X := 8.80
const MIN_Z := -4.25
const MAX_Z := 4.25
const WALL_BOTTOM := 0.40
const WALL_HEIGHT := 2.80
const WALL_THICKNESS := 0.20

static func apply(house: Node3D) -> Dictionary:
	var removed := 0
	var wall_template: Node3D
	for child in house.get_children():
		if not child is Node3D: continue
		var source: String = str(child.get_meta("ue_mesh_path", ""))
		if source.contains("Mesh_Wall_13") and absf(child.position.x + 5.3) < 0.03 and absf(child.position.z + 2.0) < 0.03:
			wall_template = child
	if wall_template == null:
		push_error("The recovered entry wall is missing; the compact tutorial cannot be sealed")
		return {"success": false, "removed": 0, "new_wall_segments": 0}
	var culled: Array[Node] = []
	for child in house.get_children():
		if not child is Node3D or not child.has_meta("ue_mesh_path"): continue
		var source: String = str(child.get_meta("ue_mesh_path", ""))
		var p: Vector3 = child.position
		# Both 8.5 m floor/ceiling pieces cross the cut at x=7.68.
		var keep_floor := source.contains("Mesh_Floor_Attic_02") and p.x < 11.0 and p.x > -6.0 and absf(p.z) < 5.0
		var keep := keep_floor or (p.x >= MIN_X and p.x <= MAX_X and p.z >= MIN_Z and p.z <= MAX_Z and p.y <= 3.50)
		if keep: continue
		culled.append(child)
		var collision := house.get_node_or_null(str(child.name) + "_Collision")
		if collision != null: culled.append(collision)
	for child in culled:
		house.remove_child(child)
		child.queue_free()
		removed += 1
	# The dressing pass suppresses implausibly scaled props. Their imported
	# concave collision siblings must disappear with them, or empty air blocks
	# Luke in the smaller house.
	for child in house.get_children():
		if not child is StaticBody3D or not str(child.name).ends_with("_Collision"): continue
		var visual_name: String = str(child.name).trim_suffix("_Collision")
		if house.has_node(NodePath(visual_name)): continue
		house.remove_child(child)
		child.queue_free()
		removed += 1
	_place_record_table(house)
	var segments := 0
	# Rear shell: one sealed wall, one and only one exterior exit remains at the front.
	for end_z in [-2.0, 0.0, 2.0, 4.0]:
		_add_wall(house, wall_template, "RearWall", Vector3(8.68, WALL_BOTTOM, end_z), 0.0, 2.0)
		segments += 1
	# Five rooms: entry; north/south middle; north/south rear. Four 1.6 m
	# doorways make two short branches from the entry to the rear chambers.
	for x in [-0.80, 3.20]:
		for span in [[-4.0, -2.8], [-1.2, 1.2], [2.8, 4.0]]:
			_add_wall(house, wall_template, "CrossWall", Vector3(x, WALL_BOTTOM, float(span[1])), 0.0, float(span[1]) - float(span[0]))
			segments += 1
		# The imported door frame tops out at 2.80 m; seal the 0.40 m gap
		# above it so the rooms don't look like disconnected exhibition panels.
		for doorway_end in [-1.20, 2.80]:
			_add_wall(house, wall_template, "DoorLintel", Vector3(x, 2.78, doorway_end), 0.0, 1.60, 0.42)
			segments += 1
	# A solid spine separates the two middle and two rear rooms. The first room
	# stays wide enough for Mara's phone and the original front-door sightline.
	# Bury each spine end inside the crossing wall. Matching the visible face
	# exactly caused coplanar caps to flicker as a pale vertical seam.
	for span in [[-0.70, 3.30], [3.30, 8.78]]:
		_add_wall(house, wall_template, "RoomSpine", Vector3(float(span[0]), WALL_BOTTOM, 0.0), -PI / 2.0, float(span[1]) - float(span[0]))
		segments += 1
	return {"success": true, "removed": removed, "new_wall_segments": segments,
		"room_count": 5, "bounds": [MIN_X, MAX_X, MIN_Z, MAX_Z]}


static func _place_record_table(house: Node3D) -> void:
	# This retained table crossed both new partitions in the compact layout.
	# Its sibling collider stores world-baked vertices, so transform that body
	# by the same old-to-new map rather than merely changing the visible mesh.
	for child in house.get_children():
		if not child is Node3D: continue
		if not str(child.get_meta("ue_mesh_path", "")).contains("SM_Coffeetable"): continue
		if child.position.distance_to(Vector3(2.670903, 0.4, 0.736698)) > 0.02: continue
		var old_pose: Transform3D = child.transform
		child.position = Vector3(1.65, 0.40, 2.94)
		child.rotation.y = PI * 0.5
		var collider := house.get_node_or_null(str(child.name) + "_Collision") as Node3D
		if collider != null:
			collider.transform = child.transform * old_pose.affine_inverse() * collider.transform
		child.set_meta("tutorial_record_table", true)

static func _add_wall(house: Node3D, template: Node3D, prefix: String, origin: Vector3, yaw: float, length: float, height: float = WALL_HEIGHT) -> void:
	var visual: Node3D = template.duplicate()
	visual.name = "%s_%02d" % [prefix, house.get_child_count()]
	visual.position = origin
	visual.rotation = Vector3(0.0, yaw, 0.0)
	visual.scale = Vector3(1.0, height / WALL_HEIGHT, length / 2.0)
	visual.set_meta("tutorial_partition", true)
	if not is_equal_approx(height, WALL_HEIGHT):
		# Preserve brick scale when a full-height source segment becomes a lintel.
		for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh_node.mesh.get_surface_count()):
				var source_material := mesh_node.get_active_material(surface) as StandardMaterial3D
				if source_material != null:
					var material := source_material.duplicate() as StandardMaterial3D
					material.uv1_scale.y *= height / WALL_HEIGHT
					mesh_node.set_surface_override_material(surface, material)
	house.add_child(visual)
	var body := StaticBody3D.new()
	body.name = visual.name + "_Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if absf(yaw) < 0.01:
		body.position = Vector3(origin.x + WALL_THICKNESS * 0.5, origin.y + height * 0.5, origin.z - length * 0.5)
		box.size = Vector3(WALL_THICKNESS, height, length)
	else:
		body.position = Vector3(origin.x + length * 0.5, origin.y + height * 0.5, origin.z + WALL_THICKNESS * 0.5)
		box.size = Vector3(length, height, WALL_THICKNESS)
	shape.shape = box
	body.add_child(shape)
	house.add_child(body)
