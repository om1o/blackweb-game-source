class_name BlackwebProps
extends RefCounted
## Original code-created pickup props. These are not recovered Arachnophobia assets.
## Units are metres. Both props rest above local Y=0; flashlight points toward -Z.


static func create(kind: StringName) -> Node3D:
	match kind:
		&"keys": return _keys()
		&"flashlight": return _flashlight()
	return null


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _mesh(parent: Node3D, mesh: Mesh, material: Material, position := Vector3.ZERO,
		rotation := Vector3.ZERO, part_name := "Part") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance


static func _cylinder(radius: float, length: float, rear_radius: float = -1.0) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if rear_radius < 0.0 else rear_radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 32
	mesh.rings = 1
	return mesh


static func _ring(inner: float, outer: float, segments: int = 32) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = segments
	mesh.ring_segments = 8
	return mesh


static func _ellipsoid(parent: Node3D, size: Vector3, material: Material,
		position: Vector3, part_name: String) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var part := _mesh(parent, sphere, material, position, Vector3.ZERO, part_name)
	part.scale = size
	return part


static func _flashlight() -> Node3D:
	var root := Node3D.new()
	root.name = "AuthoredFlashlight"
	root.set_meta("asset_origin", "Original procedural Blackweb prop")
	var body := Node3D.new()
	body.name = "FlashlightAssembly"
	body.position.y = 0.0223
	# The wider head and smaller tail both touch a tabletop in this resting pose.
	body.rotation.x = 0.056
	root.add_child(body)
	var graphite := _material(Color(0.055, 0.063, 0.070), 0.8, 0.31)
	var grip := _material(Color(0.022, 0.026, 0.030), 0.3, 0.57)
	var rubber := _material(Color(0.012, 0.015, 0.017), 0.0, 0.86)
	var metal := _material(Color(0.62, 0.65, 0.67), 0.95, 0.22)
	var reflector := _material(Color(0.78, 0.79, 0.77), 1.0, 0.13)
	reflector.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := _material(Color(0.44, 0.61, 0.67, 0.22), 0.0, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.clearcoat_enabled = true
	glass.clearcoat = 1.0
	glass.clearcoat_roughness = 0.08
	var axial := Vector3(PI * 0.5, 0.0, 0.0)
	_mesh(body, _cylinder(0.0145, 0.125), graphite, Vector3(0, 0, 0.010), axial, "AnodizedBarrel")
	_mesh(body, _cylinder(0.027, 0.045, 0.018), graphite, Vector3(0, 0, -0.075), axial, "TaperedHead")
	_mesh(body, _cylinder(0.017, 0.018), grip, Vector3(0, 0, 0.081), axial, "TailCap")
	_mesh(body, _cylinder(0.017, 0.007, 0.015), graphite, Vector3(0, 0, 0.093), axial, "TailBevel")
	for index in 9:
		_mesh(body, _ring(0.0141, 0.0156), grip, Vector3(0, 0, -0.025 + index * 0.010), axial, "GripRing%02d" % index)
	for index in 3:
		_mesh(body, _ring(0.0230 - index * 0.0013, 0.0252 - index * 0.0013), graphite,
			Vector3(0, 0, -0.088 + index * 0.007), axial, "HeadCoolingRib%02d" % index)
	# A shallow, open reflector bowl and recessed LED remain visible behind the lens.
	var bowl := _cylinder(0.022, 0.013, 0.006)
	bowl.cap_bottom = false
	_mesh(body, bowl, reflector, Vector3(0, 0, -0.090), axial, "ReflectorBowl")
	var led := _material(Color(0.93, 0.89, 0.67), 0.0, 0.32)
	_mesh(body, _cylinder(0.0031, 0.001), led, Vector3(0, 0, -0.0845), axial, "RecessedEmitter")
	_mesh(body, _cylinder(0.0218, 0.0007), glass, Vector3(0, 0, -0.0981), axial, "ProtectiveLens")
	_mesh(body, _ring(0.0218, 0.0275), metal, Vector3(0, 0, -0.0986), axial, "BrushedBezel")
	_mesh(body, _ring(0.0054, 0.0070, 24), metal, Vector3(0, 0.0141, -0.035), Vector3.ZERO, "SwitchRim")
	_mesh(body, _cylinder(0.0055, 0.0032), rubber, Vector3(0, 0.0150, -0.035), Vector3.ZERO, "RubberSwitch")
	return root


static func _keys() -> Node3D:
	var root := Node3D.new()
	root.name = "AuthoredCarKeys"
	root.set_meta("asset_origin", "Original procedural Blackweb prop")
	var metal := _material(Color(0.58, 0.61, 0.64), 0.95, 0.30)
	var blade_metal := _material(Color(0.67, 0.69, 0.67), 0.94, 0.26)
	var shell := _material(Color(0.025, 0.029, 0.034), 0.05, 0.48)
	var rubber := _material(Color(0.055, 0.060, 0.064), 0.0, 0.85)
	var icon := _material(Color(0.52, 0.55, 0.54), 0.25, 0.45)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.017
	capsule.height = 0.055
	capsule.radial_segments = 32
	capsule.rings = 8
	var trim := _mesh(root, capsule, metal, Vector3(0, 0.0077, 0), Vector3(PI * 0.5, 0, 0), "FobEdgeTrim")
	trim.scale = Vector3(1.0, 1.0, 0.43)
	var plastic := _mesh(root, capsule, shell, Vector3(0, 0.0085, -0.0001), Vector3(PI * 0.5, 0, 0), "RoundedFobShell")
	plastic.scale = Vector3(0.96, 0.98, 0.36)
	_ellipsoid(root, Vector3(0.010, 0.0022, 0.012), rubber, Vector3(0, 0.0149, -0.007), "LockButton")
	_ellipsoid(root, Vector3(0.010, 0.0022, 0.012), rubber, Vector3(0, 0.0149, 0.008), "UnlockButton")
	# Small raised lock symbols are geometry, avoiding any texture or external icon dependency.
	for center_z in [-0.007, 0.008]:
		_mesh(root, _ring(0.0015, 0.0022, 16), icon, Vector3(0, 0.0161, center_z - 0.0012), Vector3.ZERO, "LockShackle")
		_ellipsoid(root, Vector3(0.0047, 0.0007, 0.0038), icon, Vector3(0, 0.0163, center_z + 0.0012), "LockBody")
	var indicator := _material(Color(0.30, 0.025, 0.016), 0.05, 0.2)
	_ellipsoid(root, Vector3(0.0013, 0.0006, 0.0013), indicator, Vector3(0, 0.0141, -0.019), "StatusLens")
	var outline := PackedVector2Array([
		Vector2(-0.0045, -0.022), Vector2(0.0045, -0.022),
		Vector2(0.0045, -0.034), Vector2(0.0021, -0.037), Vector2(0.0045, -0.039),
		Vector2(0.0045, -0.043), Vector2(0.0010, -0.046), Vector2(0.0045, -0.049),
		Vector2(0.0045, -0.053), Vector2(0.0020, -0.055), Vector2(0.0045, -0.058),
		Vector2(0.0045, -0.064), Vector2(0.0016, -0.072), Vector2(-0.0030, -0.070),
		Vector2(-0.0045, -0.064),
	])
	_mesh(root, _extruded_polygon(outline, 0.0024), blade_metal, Vector3(0, 0.0071, 0), Vector3.ZERO, "CutKeyBlade")
	# An inset-looking dark milling channel follows the uncut edge of the blade.
	var channel := PackedVector2Array([Vector2(-0.0028, -0.027), Vector2(-0.0018, -0.027),
		Vector2(-0.0018, -0.064), Vector2(-0.0028, -0.064)])
	var channel_metal := _material(Color(0.19, 0.21, 0.22), 0.88, 0.37)
	_mesh(root, _extruded_polygon(channel, 0.00012), channel_metal, Vector3(0, 0.00835, 0), Vector3.ZERO, "BladeMillingChannel")
	_mesh(root, _ring(0.0028, 0.0044, 24), metal, Vector3(0, 0.0056, 0.028), Vector3(PI * 0.5, 0, 0), "FobAttachmentLoop")
	_mesh(root, _ring(0.0110, 0.0130, 40), metal, Vector3(0, 0.0014, 0.043), Vector3.ZERO, "SplitKeyringLower")
	_mesh(root, _ring(0.0108, 0.0128, 40), metal, Vector3(0.0003, 0.0025, 0.0434), Vector3.ZERO, "SplitKeyringUpper")
	root.rotation.y = -0.32
	return root


static func _extruded_polygon(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var triangles := Geometry2D.triangulate_polygon(outline)
	var top := thickness * 0.5
	for index in range(0, triangles.size(), 3):
		var a := outline[triangles[index]]
		var b := outline[triangles[index + 1]]
		var c := outline[triangles[index + 2]]
		_triangle(vertices, normals, uv, Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(c.x, top, c.y), Vector3.UP)
		_triangle(vertices, normals, uv, Vector3(a.x, -top, a.y), Vector3(b.x, -top, b.y), Vector3(c.x, -top, c.y), Vector3.DOWN)
	var clockwise := Geometry2D.is_polygon_clockwise(outline)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var direction := b - a
		var outward := Vector3(-direction.y, 0, direction.x).normalized()
		if not clockwise: outward = -outward
		var top_a := Vector3(a.x, top, a.y)
		var top_b := Vector3(b.x, top, b.y)
		var bottom_a := Vector3(a.x, -top, a.y)
		var bottom_b := Vector3(b.x, -top, b.y)
		_triangle(vertices, normals, uv, top_a, bottom_a, bottom_b, outward)
		_triangle(vertices, normals, uv, top_a, bottom_b, top_b, outward)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array,
		a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot front faces use clockwise winding, opposite the cross-product normal.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var temporary := b
		b = c
		c = temporary
	vertices.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	uv.append_array(PackedVector2Array([Vector2(a.x, a.z) * 20.0, Vector2(b.x, b.z) * 20.0, Vector2(c.x, c.z) * 20.0]))
