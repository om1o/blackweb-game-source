extends RefCounted
## Readable chitin under the existing practical lights and flashlight. This is
## a one-time material adaptation, with no glow, extra passes, lights or textures.

static func prepare(root: Node3D) -> void:
	var copies: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			var key := source.get_instance_id()
			if not copies.has(key):
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_color = Color(source.albedo_color.r * 1.16,
					source.albedo_color.g * 1.13, source.albedo_color.b * 1.10, source.albedo_color.a)
				material.roughness = minf(source.roughness, 0.62)
				material.metallic_specular = 0.58
				material.emission_enabled = false
				copies[key] = material
			mesh.set_surface_override_material(surface, copies[key])
