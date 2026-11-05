extends RefCounted
## Original opaque Blender strand silhouettes complement the smaller silk cards.
## Placements avoid door openings, evidence pages and the standing capsule lane.
const WEB_SCENE := "res://assets/generated/web_master/web_masters.glb"
const Surfaces = preload("res://scripts/environment_surfaces.gd")

static func placements() -> Array[Dictionary]:
	return [
		{"root": "WebRadialTorn", "position": Vector3(-4.10, 2.00, 3.43), "scale": Vector3.ONE * 0.64, "yaw": PI},
		{"root": "WebRadialTorn", "position": Vector3(4.75, 2.08, -3.60), "scale": Vector3.ONE * 0.68, "yaw": 0.0},
		{"root": "WebSaggingCanopy", "position": Vector3(-3.10, 2.98, -1.35), "scale": Vector3(0.86, 0.64, 0.85), "yaw": 0.0},
		{"root": "WebSaggingCanopy", "position": Vector3(5.35, 2.98, 2.18), "scale": Vector3(0.95, 0.72, 0.80), "yaw": 0.0},
		{"root": "WebFurnitureCocoon", "position": Vector3(-4.20, 0.425, -3.30), "scale": Vector3(0.79, 1.11, 0.50), "yaw": 0.0},
		{"root": "WebFurnitureCocoon", "position": Vector3(1.00, 0.425, -3.14), "scale": Vector3(1.20, 0.82, 0.67), "yaw": 0.0},
	]

static func orb_sites() -> Array[Dictionary]:
	return [
		{"center": Vector3(1.55, 2.40, -3.61), "u": Vector3(1.25, 0, 0), "v": Vector3(0, 1.05, 0), "normal": Vector3.BACK},
		{"center": Vector3(1.05, 2.38, 3.43), "u": Vector3(1.32, 0, 0), "v": Vector3(0, 1.10, 0), "normal": Vector3.FORWARD},
		{"center": Vector3(6.35, 2.36, 3.43), "u": Vector3(1.25, 0, 0), "v": Vector3(0, 1.05, 0), "normal": Vector3.FORWARD},
	]

static func apply(house: Node3D) -> Dictionary:
	var scene := load(WEB_SCENE) as PackedScene
	if scene == null: return {"instances": 0, "pbr_orbs": 0, "triangles": 0}
	var master := scene.instantiate()
	var group := Node3D.new()
	group.name = "BlackwebModeledSilk"
	group.set_meta("asset_origin", "Original Blackweb Blender geometry authored via Higgsfield")
	var triangles := 0
	var count := 0
	for site in placements():
		var source := master.find_child(site.root, true, false) as Node3D
		if source == null: continue
		var instance := source.duplicate() as Node3D
		instance.name = str(site.root) + str(count + 1)
		instance.position = site.position
		instance.scale = site.scale
		instance.rotation.y = site.yaw
		for child in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in range(mesh.mesh.get_surface_count()):
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
		group.add_child(instance)
		count += 1
	master.free()
	house.add_child(group)
	var cards := MeshInstance3D.new()
	cards.name = "BlackwebPbrOrbs"
	cards.set_meta("asset_origin", "TextureCan Others0015 CC0 / authored Blackweb placements")
	cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Surfaces.card_arrays(orb_sites()))
	mesh.surface_set_material(0, Surfaces.orb_material())
	cards.mesh = mesh
	house.add_child(cards)
	return {"instances": count, "pbr_orbs": orb_sites().size(), "triangles": triangles + orb_sites().size() * 2}
