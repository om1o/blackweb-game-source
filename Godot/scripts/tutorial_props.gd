extends RefCounted
## Original lightweight placeholder meshes. Dimensions are metres, no downloads.
## Both factories return an unattached Node3D with stable local-space origins.

static func make_plant() -> Node3D:
	var root := Node3D.new()
	root.name = "TutorialTerracottaPlant"
	root.set_meta("asset_origin", "Original code-authored terracotta pot and sixteen leaf blades; placeholder art")
	var clay := _material(Color(0.34, 0.13, 0.065), 0.94)
	var soil := _material(Color(0.042, 0.030, 0.017), 1.0)
	var stem_material := _material(Color(0.12, 0.17, 0.045), 0.95)
	var pot := CylinderMesh.new()
	pot.top_radius = 0.16
	pot.bottom_radius = 0.115
	pot.height = 0.27
	pot.radial_segments = 16
	pot.rings = 1
	_add(root, "TerracottaPot", pot, clay, Vector3(0, 0.135, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.142
	rim.outer_radius = 0.174
	rim.rings = 16
	rim.ring_segments = 6
	_add(root, "RoundedPotRim", rim, clay, Vector3(0, 0.267, 0))
	var dirt := CylinderMesh.new()
	dirt.top_radius = 0.145
	dirt.bottom_radius = 0.145
	dirt.height = 0.01
	dirt.radial_segments = 16
	dirt.rings = 1
	_add(root, "VisibleSoil", dirt, soil, Vector3(0, 0.258, 0))
	var stems: Array = []
	for index in 3:
		var angle := float(index) * TAU / 3.0
		stems.append([Vector3(0, 0.26, 0), Vector3(cos(angle) * 0.055, 0.82 - 0.06 * index, sin(angle) * 0.055)])
	_segments(root, "ThreeLivingStems", stems, 0.007, stem_material)
	var foliage_material := _material(Color.WHITE, 0.90)
	foliage_material.vertex_color_use_as_albedo = true
	foliage_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaves := MultiMesh.new()
	leaves.transform_format = MultiMesh.TRANSFORM_3D
	leaves.use_colors = true
	leaves.mesh = _leaf_blade()
	leaves.instance_count = 16
	for index in 16:
		var angle := float(index) * 2.399963
		var outward := Vector3(cos(angle), 0, sin(angle))
		var height := 0.36 + float(index) * 0.027
		var basis := Basis(Quaternion(Vector3.BACK, outward)) * Basis(Vector3.RIGHT, -0.12 + 0.035 * (index % 5))
		var size := 0.78 + float(index % 4) * 0.09
		basis = basis.scaled(Vector3.ONE * size)
		leaves.set_instance_transform(index, Transform3D(basis, Vector3(0, height, 0) + outward * 0.025))
		leaves.set_instance_color(index, Color(0.16 + float(index % 3) * 0.015, 0.27 + float(index % 4) * 0.016, 0.075))
	var foliage := MultiMeshInstance3D.new()
	foliage.name = "SixteenVeinedLeafBlades"
	foliage.multimesh = leaves
	foliage.material_override = foliage_material
	foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(foliage)
	return root

static func make_leather_kit() -> Node3D:
	var root := Node3D.new()
	root.name = "TutorialFoldedLeatherKit"
	root.set_meta("asset_origin", "Original code-authored folded shirt, pants, hood and paired shoes on a case; placeholder art")
	root.set_meta("origin", "Centre of the 0.75 by 0.50 metre case top plane; case extends downward")
	var leather := _material(Color(0.145, 0.078, 0.038), 0.84)
	var leather_dark := _material(Color(0.075, 0.041, 0.024), 0.90)
	var thread := _material(Color(0.34, 0.24, 0.13), 0.95)
	var canvas := _material(Color(0.065, 0.073, 0.064), 0.98)
	var metal := _material(Color(0.32, 0.29, 0.22), 0.47)
	metal.metallic = 0.68
	_box(root, "ClosedTravelCase", Vector3(0.75, 0.12, 0.50), Vector3(0, -0.06, 0), canvas)
	_box(root, "CaseLidPiping", Vector3(0.758, 0.014, 0.508), Vector3(0, -0.006, 0), leather_dark)
	_box(root, "FoldedLeatherShirt", Vector3(0.26, 0.035, 0.18), Vector3(-0.20, 0.025, -0.115), leather)
	var sleeve := _box(root, "LeftSleeveFold", Vector3(0.07, 0.022, 0.14), Vector3(-0.285, 0.052, -0.11), leather_dark)
	sleeve.rotation.y = -0.16
	sleeve = _box(root, "RightSleeveFold", Vector3(0.07, 0.022, 0.14), Vector3(-0.115, 0.052, -0.11), leather_dark)
	sleeve.rotation.y = 0.16
	var collar := TorusMesh.new()
	collar.inner_radius = 0.025
	collar.outer_radius = 0.039
	collar.rings = 12
	collar.ring_segments = 5
	_add(root, "ShirtCollar", collar, leather_dark, Vector3(-0.20, 0.059, -0.172))
	_box(root, "FoldedPantsWaist", Vector3(0.23, 0.028, 0.085), Vector3(0.135, 0.029, -0.17), leather_dark)
	_box(root, "FoldedPantsLeftLeg", Vector3(0.10, 0.035, 0.19), Vector3(0.075, 0.045, -0.10), leather)
	_box(root, "FoldedPantsRightLeg", Vector3(0.10, 0.035, 0.19), Vector3(0.195, 0.045, -0.10), leather)
	var hood := SphereMesh.new()
	hood.radius = 0.086
	hood.height = 0.14
	hood.radial_segments = 12
	hood.rings = 6
	_add(root, "FoldedLeatherHood", hood, leather, Vector3(-0.24, 0.067, 0.13))
	var opening := SphereMesh.new()
	opening.radius = 0.056
	opening.height = 0.085
	opening.radial_segments = 12
	opening.rings = 5
	var hood_opening := _add(root, "HoodFaceOpening", opening, leather_dark, Vector3(-0.24, 0.05, 0.191))
	hood_opening.scale.z = 0.30
	for side in 2:
		var x := 0.08 + float(side) * 0.14
		_box(root, "ShoeSole%d" % side, Vector3(0.105, 0.013, 0.19), Vector3(x, 0.014, 0.135), leather_dark)
		var shoe := SphereMesh.new()
		shoe.radius = 0.055
		shoe.height = 0.078
		shoe.radial_segments = 12
		shoe.rings = 5
		var toe := _add(root, "LeatherShoeToe%d" % side, shoe, leather, Vector3(x, 0.048, 0.155))
		toe.scale.z = 1.4
		_box(root, "ShoeHeel%d" % side, Vector3(0.09, 0.062, 0.07), Vector3(x, 0.044, 0.083), leather)
	var seams: Array = [
		[Vector3(-0.20, 0.045, -0.15), Vector3(-0.20, 0.045, -0.035)],
		[Vector3(-0.31, 0.045, -0.028), Vector3(-0.09, 0.045, -0.028)],
		[Vector3(0.035, 0.065, -0.18), Vector3(0.035, 0.065, -0.012)],
		[Vector3(0.235, 0.065, -0.18), Vector3(0.235, 0.065, -0.012)],
		[Vector3(0.03, 0.067, -0.013), Vector3(0.24, 0.067, -0.013)],
		[Vector3(-0.24, 0.138, 0.08), Vector3(-0.24, 0.138, 0.16)]
	]
	var buckles: Array = []
	for x in [0.08, 0.22]:
		seams.append([Vector3(x - 0.042, 0.076, 0.107), Vector3(x + 0.042, 0.076, 0.107)])
		_rect_segments(buckles, Vector3(x, 0.081, 0.11), 0.032, 0.026)
	for x in [-0.29, 0.29]:
		_box(root, "CaseLeatherStrap", Vector3(0.035, 0.007, 0.49), Vector3(x, 0.004, 0), leather_dark)
		_rect_segments(buckles, Vector3(x, 0.014, 0.214), 0.043, 0.036)
	_segments(root, "LeatherSeams", seams, 0.0025, thread)
	_segments(root, "FourSmallBuckles", buckles, 0.005, metal)
	return root

static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

static func _add(parent: Node3D, label: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, label, mesh, material, at)

static func _segments(parent: Node3D, label: String, segments: Array, width: float, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = segments.size()
	for index in segments.size():
		var from: Vector3 = segments[index][0]
		var to: Vector3 = segments[index][1]
		var axis := to - from
		var basis := Basis(Quaternion(Vector3.UP, axis.normalized())) * Basis.from_scale(Vector3(width, axis.length(), width))
		batch.set_instance_transform(index, Transform3D(basis, (from + to) * 0.5))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = batch
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func _rect_segments(out: Array, center: Vector3, width: float, depth: float) -> void:
	var corners := [center + Vector3(-width, 0, -depth) * 0.5, center + Vector3(width, 0, -depth) * 0.5,
		center + Vector3(width, 0, depth) * 0.5, center + Vector3(-width, 0, depth) * 0.5]
	for index in 4: out.append([corners[index], corners[(index + 1) % 4]])

static func _leaf_blade() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 8:
		var rows: Array = []
		for step in [segment, segment + 1]:
			var t := float(step) / 8.0
			var width := 0.066 * pow(maxf(0.0, sin(PI * t)), 0.75)
			var curve := 0.026 * sin(PI * t) + 0.026 * t * t
			rows.append([Vector3(-width, curve - 0.008, t * 0.25), Vector3(0, curve + 0.009, t * 0.25), Vector3(width, curve - 0.008, t * 0.25)])
		for triangle in [[0, 3, 1], [1, 3, 4], [1, 4, 2], [2, 4, 5]]:
			for vertex in triangle:
				var column: int = vertex % 3
				surface.set_color(Color(1.36, 1.26, 1.04) if column == 1 else Color.WHITE)
				surface.add_vertex(rows[vertex / 3][column])
	surface.generate_normals()
	return surface.commit()
