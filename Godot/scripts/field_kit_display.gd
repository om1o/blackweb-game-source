extends Node3D
## Reuse the fitted artist mesh and leather materials; no placeholder clothing.
func build(player: Node3D) -> void:
	var ids := [&"leather_shirt", &"leather_pants", &"leather_hood", &"leather_shoes"]
	var positions := [Vector3(-.20,.07,-.10),Vector3(.14,.055,-.11),Vector3(-.21,.07,.13),Vector3(.14,.06,.14)]
	var extents := [Vector3(.30,.06,.25),Vector3(.24,.065,.27),Vector3(.15,.10,.15),Vector3(.23,.08,.19)]
	for i in ids.size():
		var source := player.item_preview_source(ids[i]) as MeshInstance3D
		if source == null or source.mesh == null: continue
		var mesh := ArrayMesh.new()
		var bounds := source.mesh.get_aabb()
		# The fitted mesh vertices are in actor rest space. Lay them face-up,
		# compress only the garment depth, and retain cuffs, laces and seams.
		var center := bounds.get_center()
		var extent: Vector3 = extents[i]
		var scale_factor := Vector3(extent.x/maxf(.001,bounds.size.x),extent.z/maxf(.001,bounds.size.y),extent.y/maxf(.001,bounds.size.z))
		var basis := Basis(Vector3.RIGHT,-PI*.5)*Basis.from_scale(scale_factor)
		for surface in source.mesh.get_surface_count():
			var arrays := source.mesh.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for vertex in vertices.size():
				vertices[vertex] = basis*(vertices[vertex]-center)
				if vertex < normals.size(): normals[vertex] = (basis.inverse().transposed()*normals[vertex]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			arrays[Mesh.ARRAY_TANGENT] = null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(surface,source.mesh.surface_get_material(surface))
		var garment := MeshInstance3D.new()
		garment.name = str(ids[i])
		garment.mesh = mesh
		garment.position = positions[i]
		garment.rotation.y = -.12 if i % 2 == 0 else .10
		garment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(garment)

func refresh(claimed: Dictionary) -> void:
	for garment in get_children(): garment.visible = not claimed.has(str(garment.name))
