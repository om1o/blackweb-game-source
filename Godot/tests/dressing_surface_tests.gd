extends SceneTree
## Surface geometry must shade from the room side and remain in the playable shell.
const Dressing = preload("res://scripts/house_dressing.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var residue: ArrayMesh = Dressing._residue_mesh()
	_check_lit_surface(residue, "residue")
	_check_lit_surface(Dressing._dense_silk_mesh(), "ceiling/wall silk")
	_check_lit_surface(Dressing._web_card_mesh(), "corner silk")
	_check_lit_surface(Dressing._web_mesh(), "corner strands")
	_check_lit_surface(Dressing._radial_web_mesh(), "radial strands")
	_check_lit_surface(Dressing._hanging_veil_mesh(), "hanging strands")
	var accents: Dictionary = Dressing._accent_web_meshes()
	_check_lit_surface(accents.cards, "furniture/ceiling wraps")
	_check_lit_surface(accents.strands, "wrap strands")
	var arrays := residue.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var floor_count := 0
	var upright_drips := true
	var floor_visible := true
	for i in range(0, vertices.size(), 4):
		if normals[i].dot(Vector3.UP) > 0.99:
			floor_count += 1
			for j in range(4):
				floor_visible = floor_visible and vertices[i + j].y > 0.40 and vertices[i + j].y < 0.43
		else:
			# Image V increases downwards; drips must descend on vertical walls.
			upright_drips = upright_drips and vertices[i].y < vertices[i + 2].y and uvs[i].y > uvs[i + 2].y
	_check(floor_count == 16 and floor_visible, "all 16 floor stains sit above the recovered floor")
	_check(upright_drips, "wall atlas drips point down")
	for mesh in [residue, Dressing._web_mesh(), Dressing._radial_web_mesh(),
		Dressing._hanging_veil_mesh(), Dressing._web_card_mesh(), accents.cards, accents.strands]:
		var bounds: AABB = mesh.get_aabb()
		_check(bounds.position.x > -5.60 and bounds.end.x < 7.80, "dressing remains inside five-room X bounds")
	print(JSON.stringify({"suite": "dressing_surfaces", "checks": checks,
		"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check_lit_surface(mesh: ArrayMesh, label: String) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var valid := normals.size() == vertices.size()
	if valid:
		for i in range(0, indices.size(), 3):
			var a := indices[i]
			var edge_a := vertices[indices[i + 1]] - vertices[a]
			var edge_b := vertices[indices[i + 2]] - vertices[a]
			var clockwise_normal := -edge_a.cross(edge_b).normalized()
			valid = valid and absf(normals[a].length() - 1.0) < 0.001
			valid = valid and clockwise_normal.dot(normals[a]) > 0.999
	_check(valid, label + " normals match clockwise front faces")
	var material := mesh.surface_get_material(0) as StandardMaterial3D
	_check(material != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
		label + " responds to room and flashlight lighting")

func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed: failures.append(label)
