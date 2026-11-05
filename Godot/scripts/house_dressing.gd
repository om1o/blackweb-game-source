class_name BlackwebHouseDressing
extends RefCounted
## Reversible, authored dressing over the recovered house. Source meshes and the
## original placement manifest remain intact for provenance and future review.

# The house import report records these portable props at impossible sizes:
# 1.33 m plates in ten 18-high towers; 1.1-4.2 m books; 2.6 m card decks;
# 4.3 m cassettes; and household tools several metres long. None is used by
# the phone, keys, flashlight, door, spider, or progression interactions.
const REMOVE_MESHES := {
	"SM_Plate_03": true,
	"SM_Book_05": true,
	"SM_Book_Row_01": true,
	"SM_Pokerset_Deck": true,
	"SM_Cassette": true,
	"SM_Toothbrush": true,
	"SM_Toiletbrush": true,
	"SM_Utensil_Skimmer": true,
	"SM_Soap": true,
	"SM_Soap_02": true,
	"SM_CookingPot_04": true,
	"SM_CookingPot_02": true,
	"SM_Tray_01": true,
	"SM_Tray_04": true,
	"SM_Breadbox": true,
	"SM_Trashcan": true,
}
const PHOTO_WEB_TEXTURE := "res://assets/generated/corner_web_v1.png"
const DENSE_SILK_TEXTURE := "res://assets/generated/ceiling_silk_v2.png"
const RESIDUE_TEXTURE := "res://assets/generated/blood_goo_smears_v2.png"
const PAINTED_CABINET_SCENE := "res://assets/third_party/poly_haven/painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf"
const WORN_SHELF_SCENE := "res://assets/third_party/poly_haven/Shelf_01/Shelf_01_1k.gltf"
const CAGED_LIGHT_SCENE := "res://assets/third_party/poly_haven/caged_hanging_light/caged_hanging_light_1k.gltf"


static func apply(house: Node3D) -> Dictionary:
	var removed: Dictionary = {}
	for child in house.get_children():
		var source_mesh: String = str(child.get_meta("ue_mesh_path", ""))
		var mesh_name: String = source_mesh.get_file().get_slice(".", 0)
		if not REMOVE_MESHES.has(mesh_name):
			continue
		removed[mesh_name] = int(removed.get(mesh_name, 0)) + 1
		house.remove_child(child)
		child.queue_free()

	var webs := MeshInstance3D.new()
	webs.name = "BlackwebCornerWebs"
	webs.set_meta("asset_origin", "Original procedural Blackweb strands")
	webs.mesh = _web_mesh()
	webs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	house.add_child(webs)
	# A second silk pass gives the house open, incomplete radial webs and
	# hanging veils. Each style is one mesh/draw surface, not one node per thread.
	var orb_webs := MeshInstance3D.new()
	orb_webs.name = "BlackwebRadialWebs"
	orb_webs.set_meta("asset_origin", "Original procedural Blackweb radial silk")
	orb_webs.mesh = _radial_web_mesh()
	orb_webs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	house.add_child(orb_webs)
	var hanging_webs := MeshInstance3D.new()
	hanging_webs.name = "BlackwebHangingVeils"
	hanging_webs.set_meta("asset_origin", "Original procedural Blackweb hanging silk")
	hanging_webs.mesh = _hanging_veil_mesh()
	hanging_webs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	house.add_child(hanging_webs)
	var residue := MeshInstance3D.new()
	residue.name = "BlackwebBloodAndGoo"
	residue.set_meta("asset_origin", "Original Blackweb blood and black-residue decals")
	residue.mesh = _residue_mesh()
	residue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	house.add_child(residue)
	var dense_silk_cards := 0
	if ResourceLoader.exists(DENSE_SILK_TEXTURE):
		var dense_silk := MeshInstance3D.new()
		dense_silk.name = "BlackwebDenseSilkCurtains"
		dense_silk.set_meta("asset_origin", "Original generated Blackweb aged silk curtain")
		dense_silk.mesh = _dense_silk_mesh()
		dense_silk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		house.add_child(dense_silk)
		dense_silk_cards = _dense_silk_sites().size() * 2
	var photo_web_cards := 0
	var photo_web_triangles := 0
	if ResourceLoader.exists(PHOTO_WEB_TEXTURE):
		var photo_webs := MeshInstance3D.new()
		photo_webs.name = "BlackwebPhotoWebs"
		photo_webs.set_meta("asset_origin", "Original generated Blackweb corner-web texture")
		photo_webs.mesh = _web_card_mesh()
		photo_webs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		house.add_child(photo_webs)
		photo_web_cards = 14
		photo_web_triangles = photo_webs.mesh.surface_get_array_index_len(0) / 3
		var accents := _accent_web_meshes()
		var accent_cards := MeshInstance3D.new()
		accent_cards.name = "BlackwebSheetAndWrapCards"
		accent_cards.set_meta("asset_origin", "Original generated Blackweb web texture")
		accent_cards.mesh = accents.cards
		accent_cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		house.add_child(accent_cards)
		var accent_strands := MeshInstance3D.new()
		accent_strands.name = "BlackwebSheetAndWrapStrands"
		accent_strands.set_meta("asset_origin", "Original procedural Blackweb strands")
		accent_strands.mesh = accents.strands
		accent_strands.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		house.add_child(accent_strands)
	else:
		push_warning("Generated corner-web texture unavailable; keeping procedural strands")
	var cabinet_count := 0
	if ResourceLoader.exists(PAINTED_CABINET_SCENE):
		var cabinet_scene := load(PAINTED_CABINET_SCENE) as PackedScene
		if cabinet_scene != null:
			var cabinet := cabinet_scene.instantiate() as Node3D
			cabinet.name = "PaintedWoodenCabinet"
			cabinet.position = Vector3(-4.20, 0.40, -3.55)
			cabinet.set_meta("asset_origin", "Poly Haven Painted Wooden Cabinet (CC0)")
			_disable_mesh_shadows(cabinet)
			var cabinet_body := StaticBody3D.new()
			cabinet_body.name = "FurnitureCollision"
			var cabinet_shape := CollisionShape3D.new()
			cabinet_shape.name = "CabinetBox"
			var box := BoxShape3D.new()
			box.size = Vector3(1.20, 1.18, 0.55)
			cabinet_shape.shape = box
			cabinet_shape.position.y = 0.59
			cabinet_body.add_child(cabinet_shape)
			cabinet.add_child(cabinet_body)
			house.add_child(cabinet)
			cabinet_count = 1
	else:
		push_warning("CC0 painted cabinet unavailable; house remains playable")
	var shelf_count := 0
	if ResourceLoader.exists(WORN_SHELF_SCENE):
		var shelf_scene := load(WORN_SHELF_SCENE) as PackedScene
		if shelf_scene != null:
			var shelf := shelf_scene.instantiate() as Node3D
			shelf.name = "WornWallShelf"
			shelf.position = Vector3(-1.90, 0.40, -3.62)
			shelf.set_meta("asset_origin", "Poly Haven Shelf 01 (CC0)")
			_disable_mesh_shadows(shelf)
			var shelf_body := StaticBody3D.new()
			shelf_body.name = "FurnitureCollision"
			var shelf_shape := CollisionShape3D.new()
			shelf_shape.name = "ShelfBox"
			var shelf_box := BoxShape3D.new()
			shelf_box.size = Vector3(1.04, 2.08, 0.28)
			shelf_shape.shape = shelf_box
			shelf_shape.position = Vector3(0.0, 1.04, 0.13)
			shelf_body.add_child(shelf_shape)
			shelf.add_child(shelf_body)
			house.add_child(shelf)
			shelf_count = 1
	else:
		push_warning("CC0 worn shelf unavailable; house remains playable")
	var caged_fixture_count := 0
	if ResourceLoader.exists(CAGED_LIGHT_SCENE):
		var fixture_scene := load(CAGED_LIGHT_SCENE) as PackedScene
		if fixture_scene != null:
			var fixture := fixture_scene.instantiate() as Node3D
			fixture.name = "CagedCeilingFixture"
			# Align the mesh with a recovered practical; the fixture adds no Light3D.
			fixture.position = Vector3(0.21, 3.04, 0.41)
			fixture.set_meta("asset_origin", "Poly Haven Caged Hanging Light (CC0)")
			_disable_mesh_shadows(fixture)
			house.add_child(fixture)
			caged_fixture_count = 1
	else:
		push_warning("CC0 caged fixture unavailable; house remains playable")
	return {"removed": removed, "removed_total": _sum_counts(removed), "web_fans": 7,
		"web_triangles": webs.mesh.surface_get_array_index_len(0) / 3,
		"radial_webs": _radial_web_sites().size(),
		"radial_web_triangles": orb_webs.mesh.surface_get_array_index_len(0) / 3,
		"hanging_veils": _hanging_veil_sites().size(),
		"hanging_veil_triangles": hanging_webs.mesh.surface_get_array_index_len(0) / 3,
		"residue_decals": _residue_sites().size(),
		"residue_triangles": residue.mesh.surface_get_array_index_len(0) / 3,
		"residue_generated_atlas": ResourceLoader.exists(RESIDUE_TEXTURE),
		"dense_silk_cards": dense_silk_cards,
		"photo_web_cards": photo_web_cards, "photo_web_triangles": photo_web_triangles,
		"ceiling_sheet_cards": 5 if photo_web_cards > 0 else 0,
		"object_wrap_cards": 6 if photo_web_cards > 0 else 0,
		"cabinet_count": cabinet_count, "shelf_count": shelf_count,
		"caged_fixture_count": caged_fixture_count}


static func _disable_mesh_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_mesh_shadows(child)


static func _sum_counts(counts: Dictionary) -> int:
	var total := 0
	for count in counts.values():
		total += int(count)
	return total


static func _web_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	# Small fans sit high on wall corners. They do not cross the walkable route,
	# add collision, or request additional lights or shadow maps.
	var fans := _web_sites()
	for fan in fans:
		var origin: Vector3 = fan.origin
		var u: Vector3 = fan.u
		var v: Vector3 = fan.v
		var normal: Vector3 = fan.normal
		for radial in range(7):
			var t := float(radial) / 6.0
			var edge: Vector3 = origin + u.lerp(v, t)
			_append_strand(vertices, indices, origin, edge, normal, 0.007)
		for ring in range(1, 6):
			var radius := float(ring) / 6.0
			for spoke in range(6):
				var a: Vector3 = origin + u.lerp(v, float(spoke) / 6.0) * radius
				var b: Vector3 = origin + u.lerp(v, float(spoke + 1) / 6.0) * radius
				_append_strand(vertices, indices, a, b, normal, 0.005)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _strand_normals(vertices, indices)
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var silk := StandardMaterial3D.new()
	silk.resource_name = "Procedural spider silk"
	silk.albedo_color = Color(0.57, 0.64, 0.64, 0.70)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	silk.cull_mode = BaseMaterial3D.CULL_DISABLED
	silk.no_depth_test = false
	mesh.surface_set_material(0, silk)
	return mesh


static func _web_sites() -> Array[Dictionary]:
	return [
		{"origin": Vector3(-4.90, 3.05, -3.75), "u": Vector3(1.05, 0, 0), "v": Vector3(0, -0.65, 0), "normal": Vector3(0, 0, 1)},
		{"origin": Vector3(2.40, 3.03, -3.75), "u": Vector3(-1.10, 0, 0), "v": Vector3(0, -0.66, 0), "normal": Vector3(0, 0, 1)},
		{"origin": Vector3(-4.90, 3.05, 3.55), "u": Vector3(1.20, 0, 0), "v": Vector3(0, -0.68, 0), "normal": Vector3(0, 0, -1)},
		{"origin": Vector3(3.70, 3.03, 3.55), "u": Vector3(-1.10, 0, 0), "v": Vector3(0, -0.65, 0), "normal": Vector3(0, 0, -1)},
		{"origin": Vector3(5.80, 3.02, -3.75), "u": Vector3(-1.05, 0, 0), "v": Vector3(0, -0.63, 0), "normal": Vector3(0, 0, 1)},
		{"origin": Vector3(4.55, 3.03, 0.255), "u": Vector3(1.00, 0, 0), "v": Vector3(0, -0.62, 0), "normal": Vector3(0, 0, 1)},
		{"origin": Vector3(6.95, 3.03, -0.055), "u": Vector3(-1.05, 0, 0), "v": Vector3(0, -0.63, 0), "normal": Vector3(0, 0, -1)},
	]


static func _radial_web_sites() -> Array[Dictionary]:
	# Low-density partial wheels sit on high, non-interactive wall panels. Their
	# missing sectors and irregular concentric lines keep them from reading as
	# repeated perfect targets or covering a pickup prompt.
	return [
		{"center": Vector3(-2.87, 2.54, -3.56), "radius": 0.45, "phase": 0.2},
		{"center": Vector3(1.42, 2.47, 3.38), "radius": 0.54, "phase": 0.8},
		{"center": Vector3(4.48, 2.57, -3.56), "radius": 0.43, "phase": 1.4},
		{"center": Vector3(6.77, 2.53, 3.38), "radius": 0.52, "phase": 2.2},
		{"center": Vector3(6.62, 2.52, -3.56), "radius": 0.47, "phase": 2.8},
	]


static func _radial_web_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const SPOKES := 13
	const RINGS := 6
	for site in _radial_web_sites():
		var center: Vector3 = site.center
		var radius: float = site.radius
		var phase: float = site.phase
		var normal := Vector3(0, 0, 1)
		for spoke in range(SPOKES):
			# Lose a few strands where the old web has torn away.
			if (spoke + int(phase * 10.0)) % 9 == 0:
				continue
			var previous := center
			for ring in range(1, RINGS + 1):
				var point := _radial_point(center, radius, phase, spoke, ring, SPOKES, RINGS)
				_append_strand(vertices, indices, previous, point, normal, 0.0045)
				previous = point
		for ring in range(1, RINGS + 1):
			for spoke in range(SPOKES):
				if (spoke + ring * 2 + int(phase * 10.0)) % 11 == 0:
					continue
				var a := _radial_point(center, radius, phase, spoke, ring, SPOKES, RINGS)
				var b := _radial_point(center, radius, phase, spoke + 1, ring, SPOKES, RINGS)
				# A shallow chord gives the spiral its hand-spun, sagging cadence.
				var mid := a.lerp(b, 0.5) + Vector3(0, -0.012 * float(ring) / float(RINGS), 0)
				_append_strand(vertices, indices, a, mid, normal, 0.003)
				_append_strand(vertices, indices, mid, b, normal, 0.003)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _strand_normals(vertices, indices)
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _strand_material("Incomplete radial silk", Color(0.61, 0.68, 0.68, 0.58)))
	return mesh


static func _radial_point(center: Vector3, radius: float, phase: float, spoke: int,
		ring: int, spoke_count: int, ring_count: int) -> Vector3:
	var theta := TAU * float(spoke) / float(spoke_count) + phase
	var radial := radius * float(ring) / float(ring_count)
	radial *= 1.0 + 0.075 * sin(float(spoke * 7 + ring * 3) + phase * 5.0)
	return center + Vector3(cos(theta) * radial, sin(theta) * radial * 0.78, 0)


static func _hanging_veil_sites() -> Array[Dictionary]:
	return [
		{"start": Vector3(-3.65, 2.95, -3.14), "width": 0.80, "length": 0.78},
		{"start": Vector3(-0.65, 2.95, 3.10), "width": 0.90, "length": 0.96},
		{"start": Vector3(3.48, 2.95, -3.14), "width": 0.82, "length": 0.72},
		{"start": Vector3(6.25, 2.95, 3.10), "width": 0.94, "length": 0.90},
		{"start": Vector3(5.55, 2.95, -3.14), "width": 0.88, "length": 0.86},
	]


static func _hanging_veil_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for site_index in range(_hanging_veil_sites().size()):
		var site: Dictionary = _hanging_veil_sites()[site_index]
		var start: Vector3 = site.start
		var width: float = site.width
		var length: float = site.length
		var strands := 9
		var sections := 7
		for filament in range(strands):
			var ratio := float(filament) / float(strands - 1)
			var bottom: float = length * (0.58 + 0.38 * abs(sin(float(filament * 4 + site_index * 3))))
			var previous := start + Vector3(width * ratio, 0, 0)
			for section in range(1, sections + 1):
				var t := float(section) / float(sections)
				var point := start + Vector3(width * ratio + sin(t * 5.0 + float(filament) * 1.6) * 0.035 * t,
					-bottom * t, sin(t * PI) * 0.11 + sin(t * 7.0 + float(filament)) * 0.014)
				_append_strand(vertices, indices, previous, point, Vector3(0, 0, 1), 0.004)
				previous = point
		for rung in range(1, 5):
			var t := float(rung) / 6.0
			for filament in range(strands - 1):
				if (filament + rung + site_index) % 4 == 0:
					continue
				var a := start + Vector3(width * float(filament) / float(strands - 1), -length * t * 0.75,
					sin(t * PI) * 0.07)
				var b := start + Vector3(width * float(filament + 1) / float(strands - 1),
					-length * t * 0.75 - 0.035, sin(t * PI) * 0.07)
				_append_strand(vertices, indices, a, b, Vector3(0, 0, 1), 0.0028)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _strand_normals(vertices, indices)
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _strand_material("Hanging silk veils", Color(0.48, 0.55, 0.56, 0.50)))
	return mesh


static func _strand_material(name: String, color: Color) -> StandardMaterial3D:
	var silk := StandardMaterial3D.new()
	silk.resource_name = name
	silk.albedo_color = color
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	silk.cull_mode = BaseMaterial3D.CULL_DISABLED
	return silk


static func _residue_sites() -> Array[Dictionary]:
	# Decals are flush with masonry, static furniture and wall-edge floorboards.
	# No card sits in the centre lane, on a functional search unit, or on a pickup.
	var sites: Array[Dictionary] = [
		{"center": Vector3(-4.27, 1.77, -3.72), "u": Vector3(0.77, 0, 0), "v": Vector3(0, 0.52, 0), "kind": 0, "tilt": 0.08},
		{"center": Vector3(-2.15, 1.27, -3.72), "u": Vector3(0.61, 0, 0), "v": Vector3(0, 0.46, 0), "kind": 0, "tilt": -0.11},
		{"center": Vector3(-0.24, 1.92, 3.52), "u": Vector3(0.88, 0, 0), "v": Vector3(0, 0.54, 0), "kind": 0, "tilt": 0.15},
		{"center": Vector3(1.67, 1.16, 3.52), "u": Vector3(0.56, 0, 0), "v": Vector3(0, 0.49, 0), "kind": 0, "tilt": -0.08},
		{"center": Vector3(3.51, 1.74, -3.72), "u": Vector3(0.93, 0, 0), "v": Vector3(0, 0.58, 0), "kind": 0, "tilt": 0.07},
		{"center": Vector3(5.72, 1.05, -3.72), "u": Vector3(0.62, 0, 0), "v": Vector3(0, 0.44, 0), "kind": 0, "tilt": -0.18},
		{"center": Vector3(6.96, 1.92, 3.52), "u": Vector3(0.79, 0, 0), "v": Vector3(0, 0.51, 0), "kind": 0, "tilt": 0.10},
		{"center": Vector3(8.67, 1.43, -3.72), "u": Vector3(0.69, 0, 0), "v": Vector3(0, 0.53, 0), "kind": 0, "tilt": -0.12},
		{"center": Vector3(10.35, 1.94, 3.52), "u": Vector3(0.83, 0, 0), "v": Vector3(0, 0.60, 0), "kind": 0, "tilt": 0.09},
		{"center": Vector3(12.11, 1.25, -3.72), "u": Vector3(0.72, 0, 0), "v": Vector3(0, 0.46, 0), "kind": 0, "tilt": -0.06},
		{"center": Vector3(-3.49, 2.35, -3.70), "u": Vector3(0.73, 0, 0), "v": Vector3(0, 0.46, 0), "kind": 1, "tilt": -0.04},
		{"center": Vector3(-1.45, 2.23, 3.50), "u": Vector3(0.77, 0, 0), "v": Vector3(0, 0.51, 0), "kind": 1, "tilt": 0.13},
		{"center": Vector3(0.77, 0.92, -3.70), "u": Vector3(0.58, 0, 0), "v": Vector3(0, 0.43, 0), "kind": 1, "tilt": -0.11},
		{"center": Vector3(2.42, 2.36, -3.70), "u": Vector3(0.81, 0, 0), "v": Vector3(0, 0.53, 0), "kind": 1, "tilt": 0.07},
		{"center": Vector3(4.62, 2.26, 3.50), "u": Vector3(0.75, 0, 0), "v": Vector3(0, 0.50, 0), "kind": 1, "tilt": -0.14},
		{"center": Vector3(6.24, 0.83, -3.70), "u": Vector3(0.64, 0, 0), "v": Vector3(0, 0.44, 0), "kind": 1, "tilt": 0.16},
		{"center": Vector3(7.73, 2.20, 3.50), "u": Vector3(0.79, 0, 0), "v": Vector3(0, 0.54, 0), "kind": 1, "tilt": 0.06},
		{"center": Vector3(9.38, 2.40, -3.70), "u": Vector3(0.83, 0, 0), "v": Vector3(0, 0.60, 0), "kind": 1, "tilt": -0.05},
		{"center": Vector3(11.11, 0.87, 3.50), "u": Vector3(0.69, 0, 0), "v": Vector3(0, 0.50, 0), "kind": 1, "tilt": 0.14},
		{"center": Vector3(12.18, 2.29, -3.70), "u": Vector3(0.72, 0, 0), "v": Vector3(0, 0.47, 0), "kind": 1, "tilt": -0.12},
		{"center": Vector3(-4.52, 1.00, -3.19), "u": Vector3(0.40, 0, 0), "v": Vector3(0, 0.31, 0), "kind": 0, "tilt": -0.14},
		{"center": Vector3(-4.04, 0.86, -3.19), "u": Vector3(0.38, 0, 0), "v": Vector3(0, 0.35, 0), "kind": 1, "tilt": 0.12},
		{"center": Vector3(-1.90, 1.42, -3.27), "u": Vector3(0.41, 0, 0), "v": Vector3(0, 0.38, 0), "kind": 1, "tilt": -0.13},
		{"center": Vector3(-1.53, 1.81, -3.27), "u": Vector3(0.33, 0, 0), "v": Vector3(0, 0.27, 0), "kind": 0, "tilt": 0.10},
		{"center": Vector3(-4.39, 1.35, -3.19), "u": Vector3(0.36, 0, 0), "v": Vector3(0, 0.30, 0), "kind": 1, "tilt": 0.04},
		{"center": Vector3(-1.61, 2.06, -3.27), "u": Vector3(0.38, 0, 0), "v": Vector3(0, 0.32, 0), "kind": 1, "tilt": -0.08},
		{"center": Vector3(-3.55, 0.026, -3.15), "u": Vector3(0.67, 0, 0), "v": Vector3(0, 0, 0.34), "kind": 0, "tilt": 0.05},
		{"center": Vector3(0.78, 0.026, 3.05), "u": Vector3(0.61, 0, 0), "v": Vector3(0, 0, 0.37), "kind": 1, "tilt": -0.10},
		{"center": Vector3(7.92, 0.026, -3.05), "u": Vector3(0.74, 0, 0), "v": Vector3(0, 0, 0.42), "kind": 0, "tilt": 0.11},
		{"center": Vector3(10.86, 0.026, 3.02), "u": Vector3(0.65, 0, 0), "v": Vector3(0, 0, 0.40), "kind": 1, "tilt": -0.06},
	]
	# Repeat one imported atlas as small, irregular stains rather than loading
	# many high-resolution images. These patches cover the compact five-room
	# shell's perimeter and both faces of its solid interior spine.
	var wall_x := [-4.88, -4.18, -3.46, -2.72, -2.02, -1.28,
		-0.50, 0.23, 0.97, 1.70, 2.42, 3.46, 4.18, 4.92, 5.66, 6.40, 7.10]
	for wall_index in range(2):
		var z := -3.69 if wall_index == 0 else 3.51
		for index in range(wall_x.size()):
			var x: float = wall_x[index]
			for row in range(2):
				var high := row == 1
				sites.append({"center": Vector3(x + 0.10 * sin(float(index * 3 + row)),
					1.64 if high else 0.62, z),
					"u": Vector3(0.40 + 0.20 * float((index + row) % 3), 0, 0),
					"v": Vector3(0, 0.39 + 0.18 * float((index + wall_index) % 3), 0),
					"kind": (index + row + wall_index) % 2,
					"tilt": 0.16 * sin(float(index * 4 + row * 7))})
	for face in range(2):
		var z := -0.035 if face == 0 else 0.235
		for index in range(12):
			var x := -0.30 + float(index) * 0.64
			sites.append({"center": Vector3(x, 0.75 + float(index % 3) * 0.58, z),
				"u": Vector3(0.36 + 0.12 * float(index % 3), 0, 0),
				"v": Vector3(0, 0.42 + 0.11 * float((index + face) % 3), 0),
				"normal": Vector3.FORWARD if face == 0 else Vector3.BACK,
				"kind": (index + face) % 2, "tilt": 0.12 * sin(float(index * 5 + face))})
	# The short cross walls are what Luke sees immediately on entering. Dress
	# both faces as heavily as the perimeter, keeping the four doorway gaps free.
	for cross_x in [-0.80, 3.20]:
		for face in range(2):
			var surface_x: float = cross_x - 0.08 if face == 0 else cross_x + 0.28
			for index in range(4):
				var z: float = [-3.35, -0.83, 0.40, 3.35][index]
				sites.append({"center": Vector3(surface_x, 0.92 + 0.37 * float(index % 2), z),
					"u": Vector3(0, 0, 0.50 + 0.12 * float(index % 2)),
					"v": Vector3(0, 0.42 + 0.11 * float((index + face) % 2), 0),
					"normal": Vector3.LEFT if face == 0 else Vector3.RIGHT,
					"kind": (index + face) % 2, "tilt": 0.11 * sin(float(index * 3 + face))})
	for index in range(12):
		sites.append({"center": Vector3(-4.45 + float(index) * 1.03, 0.026,
			-3.17 if index % 2 == 0 else 3.05),
			"u": Vector3(0.52 + 0.08 * float(index % 3), 0, 0),
			"v": Vector3(0, 0, 0.27 + 0.07 * float(index % 2)),
			"kind": index % 2, "tilt": 0.11 * sin(float(index * 6))})
	# The recovered floor surface is at 0.40 m, not the import origin. Keep all
	# stains in the cropped house and just above the boards, without z-fighting.
	for site in sites:
		var center: Vector3 = site.center
		if center.x > 7.35:
			center.x = 3.70 + fmod(center.x - 7.35, 3.40)
		if absf(site.v.y) < 0.01:
			center.y = 0.414
		site.center = center
		if not site.has("normal"):
			site.normal = Vector3.UP if absf(site.v.y) < 0.01 else (Vector3.FORWARD if center.z > 0.0 else Vector3.BACK)
	return sites


static func _residue_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for site in _residue_sites():
		var center: Vector3 = site.center
		var u: Vector3 = site.u
		var v: Vector3 = site.v
		var axis := u.cross(v).normalized()
		var tilt: float = site.tilt
		var rotation := Basis(axis, tilt)
		u = rotation * u
		v = rotation * v
		var base := vertices.size()
		vertices.append_array(PackedVector3Array([
			center - u * 0.5 - v * 0.5, center + u * 0.5 - v * 0.5,
			center - u * 0.5 + v * 0.5, center + u * 0.5 + v * 0.5,
		]))
		# Imported photo decals need surface normals for flashlight shading. The
		# unlit fallback would otherwise turn both blood and goo pure black.
		var outward: Vector3 = site.normal
		normals.append_array(PackedVector3Array([outward, outward, outward, outward]))
		var left: float = 0.01 if int(site.kind) == 0 else 0.51
		var right: float = 0.49 if int(site.kind) == 0 else 0.99
		uvs.append_array(PackedVector2Array([
			Vector2(left, 0.98), Vector2(right, 0.98),
			Vector2(left, 0.02), Vector2(right, 0.02),
		]))
		_append_facing_quad(indices, base, u, v, outward)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _residue_material())
	return mesh


static func _residue_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Dried blood and arachnoid residue"
	material.albedo_texture = load(RESIDUE_TEXTURE) if ResourceLoader.exists(RESIDUE_TEXTURE) else _fallback_residue_texture()
	material.albedo_color = Color(0.90, 0.84, 0.80, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.20
	material.roughness = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _fallback_residue_texture() -> ImageTexture:
	# Source atlas generation may be unavailable offline. This deterministic
	# 512x256 alpha cutout keeps the dressing readable without a solid rectangle.
	var image := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(512):
			var black := x >= 256
			var local_x := float(x % 256) / 127.5 - 1.0
			var local_y := float(y) / 127.5 - 1.0
			var wobble := 0.12 * sin(local_x * 11.0 + (2.0 if black else 0.0))
			var dist := Vector2(local_x * (0.91 if black else 1.04), (local_y + wobble) * 1.28).length()
			var grain := 0.5 + 0.5 * sin(float(x) * 0.37 + float(y) * 1.33) * sin(float(y) * 0.71)
			var alpha := clampf((0.93 - dist) * 2.8 + (grain - 0.5) * 0.21, 0.0, 0.83)
			if local_y > 0.05 and local_y < 0.86:
				for drip in [-0.53, 0.16, 0.58]:
					var offset: float = drip + 0.03 * sin(local_y * 7.0 + drip * 6.0)
					if abs(local_x - offset) < (0.035 if black else 0.022):
						alpha = maxf(alpha, (0.58 if black else 0.47) * (1.0 - local_y * 0.35))
			var color := Color(0.055, 0.044, 0.045, alpha) if black else Color(0.20, 0.032, 0.025, alpha)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _web_card_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# One wall card and one shallow projecting card at all seven high corners.
	# The existing strand mesh gives them real 3D thread silhouettes.
	var sites := _web_sites()
	for index in range(sites.size()):
		var fan: Dictionary = sites[index]
		var origin: Vector3 = fan.origin + fan.normal * 0.012
		var u: Vector3 = fan.u
		var v: Vector3 = fan.v
		var normal: Vector3 = fan.normal
		_append_web_card(vertices, normals, uvs, indices, origin, origin + u * 0.95, origin + v * 0.94, normal)
		_append_web_card(vertices, normals, uvs, indices, origin + normal * 0.025,
			origin + u * 0.72 + normal * 0.33,
			origin + v * 0.78 + normal * 0.12, normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _photo_web_material())
	return mesh


static func _accent_web_meshes() -> Dictionary:
	var card_vertices := PackedVector3Array()
	var card_normals := PackedVector3Array()
	var card_uvs := PackedVector2Array()
	var card_indices := PackedInt32Array()
	var strand_vertices := PackedVector3Array()
	var strand_indices := PackedInt32Array()
	# Ceiling sheet bridges are low, shallow spans between wall and ceiling,
	# kept above the player's head and away from the centre walking lane.
	for bridge in [
		{"a": Vector3(-1.76, 2.97, -3.46), "b": Vector3(-0.58, 2.97, -3.46), "c": Vector3(-1.18, 2.15, -2.53)},
		{"a": Vector3(3.87, 2.97, 3.41), "b": Vector3(5.01, 2.97, 3.41), "c": Vector3(4.42, 2.14, 2.46)},
		{"a": Vector3(5.90, 2.97, -3.46), "b": Vector3(7.22, 2.97, -3.46), "c": Vector3(6.56, 2.12, -2.35)},
		{"a": Vector3(0.40, 2.97, 0.27), "b": Vector3(1.58, 2.97, 0.27), "c": Vector3(0.99, 2.15, 1.27)},
		{"a": Vector3(5.86, 2.97, 3.41), "b": Vector3(7.12, 2.97, 3.41), "c": Vector3(6.49, 2.12, 2.35)},
	]:
		var a: Vector3 = bridge.a
		var b: Vector3 = bridge.b
		var c: Vector3 = bridge.c
		_append_web_card(card_vertices, card_normals, card_uvs, card_indices, a, b, c, Vector3.DOWN)
		_append_strand(strand_vertices, strand_indices, a, b, Vector3.UP, 0.005)
		_append_strand(strand_vertices, strand_indices, a, c, Vector3.UP, 0.005)
		_append_strand(strand_vertices, strand_indices, b, c, Vector3.UP, 0.005)
		for ring in range(1, 5):
			var t := float(ring) / 5.0
			_append_strand(strand_vertices, strand_indices, a.lerp(c, t), b.lerp(c, t), Vector3.UP, 0.003)
	# Localized cross-wraps dress only static, non-interactive furniture.
	for wrap in [
		{"a": Vector3(-4.68, 1.60, -3.23), "b": Vector3(-4.23, 1.60, -3.23), "c": Vector3(-4.68, 1.21, -3.23)},
		{"a": Vector3(-1.88, 2.42, -3.31), "b": Vector3(-1.44, 2.42, -3.31), "c": Vector3(-1.44, 2.01, -3.31)},
		{"a": Vector3(-4.22, 1.59, -3.23), "b": Vector3(-3.82, 1.59, -3.23), "c": Vector3(-3.82, 1.23, -3.23)},
		{"a": Vector3(-2.40, 2.43, -3.31), "b": Vector3(-1.97, 2.43, -3.31), "c": Vector3(-2.40, 2.06, -3.31)},
		{"a": Vector3(-4.63, 0.77, -3.23), "b": Vector3(-4.25, 0.77, -3.23), "c": Vector3(-4.63, 0.48, -3.23)},
		{"a": Vector3(-1.88, 1.70, -3.31), "b": Vector3(-1.51, 1.70, -3.31), "c": Vector3(-1.51, 1.39, -3.31)},
	]:
		var a: Vector3 = wrap.a
		var b: Vector3 = wrap.b
		var c: Vector3 = wrap.c
		_append_web_card(card_vertices, card_normals, card_uvs, card_indices, a, b, c, Vector3.BACK)
		_append_strand(strand_vertices, strand_indices, a, b, Vector3(0, 0, 1), 0.004)
		_append_strand(strand_vertices, strand_indices, b, c, Vector3(0, 0, 1), 0.004)
		_append_strand(strand_vertices, strand_indices, c, a, Vector3(0, 0, 1), 0.004)
		for ring in range(1, 5):
			var t := float(ring) / 5.0
			_append_strand(strand_vertices, strand_indices, a.lerp(c, t), b.lerp(c, t), Vector3(0, 0, 1), 0.003)
	var card_arrays := []
	card_arrays.resize(Mesh.ARRAY_MAX)
	card_arrays[Mesh.ARRAY_VERTEX] = card_vertices
	card_arrays[Mesh.ARRAY_NORMAL] = card_normals
	card_arrays[Mesh.ARRAY_TEX_UV] = card_uvs
	card_arrays[Mesh.ARRAY_INDEX] = card_indices
	var cards := ArrayMesh.new()
	cards.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, card_arrays)
	cards.surface_set_material(0, _photo_web_material())
	var strand_arrays := []
	strand_arrays.resize(Mesh.ARRAY_MAX)
	strand_arrays[Mesh.ARRAY_VERTEX] = strand_vertices
	strand_arrays[Mesh.ARRAY_NORMAL] = _strand_normals(strand_vertices, strand_indices)
	strand_arrays[Mesh.ARRAY_INDEX] = strand_indices
	var strands := ArrayMesh.new()
	strands.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, strand_arrays)
	var silk := StandardMaterial3D.new()
	silk.resource_name = "Ceiling and furniture web strands"
	silk.albedo_color = Color(0.57, 0.64, 0.64, 0.70)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	silk.cull_mode = BaseMaterial3D.CULL_DISABLED
	strands.surface_set_material(0, silk)
	return {"cards": cards, "strands": strands}


static func _photo_web_material() -> StandardMaterial3D:
	var silk := StandardMaterial3D.new()
	silk.resource_name = "Draped spider-web cards"
	silk.albedo_texture = load(PHOTO_WEB_TEXTURE)
	# The source cutout is nearly white. A warmer, dimmer tint keeps it from
	# reading like a paper sticker when Luke's flashlight crosses a brick wall.
	silk.albedo_color = Color(0.56, 0.55, 0.52, 0.78)
	# Scissor rejects low-alpha image haze, leaving open strands without a slab.
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	silk.alpha_scissor_threshold = 0.28
	silk.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	silk.roughness = 1.0
	silk.cull_mode = BaseMaterial3D.CULL_DISABLED
	return silk

static func _dense_silk_sites() -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	# Pair each wall-mounted sheet with a shallow projecting sheet, so the
	# growth has volume when the flashlight passes it. All lower edges stay
	# above the player's standing height and away from the four door gaps.
	var x_positions := [-4.90, -3.62, -2.34, -0.52, 0.74, 2.00,
		3.46, 4.72, 5.98]
	for back in range(2):
		var z := -3.57 if back == 0 else 3.39
		var normal := Vector3(0, 0, 1 if back == 0 else -1)
		for index in range(x_positions.size()):
			sites.append({"origin": Vector3(x_positions[index], 2.96, z),
				"horizontal": Vector3(1.04, 0, 0), "normal": normal,
				"height": 0.70 + 0.12 * float((index + back) % 3)})
	for face in range(2):
		var z := -0.055 if face == 0 else 0.255
		var normal := Vector3(0, 0, -1 if face == 0 else 1)
		for index in range(6):
			var x := 0.02 + float(index) * 1.23
			sites.append({"origin": Vector3(x, 2.96, z),
				"horizontal": Vector3(1.02, 0, 0), "normal": normal,
				"height": 0.72 + 0.10 * float((index + face) % 3)})
	for wall_x in [-0.80, 3.20]:
		for face in range(2):
			var surface_x: float = wall_x - 0.10 if face == 0 else wall_x + 0.30
			var normal := Vector3(-1, 0, 0) if face == 0 else Vector3(1, 0, 0)
			for z in [-3.90, -1.08, 0.02, 2.92]:
				sites.append({"origin": Vector3(surface_x, 3.00, float(z)),
					"horizontal": Vector3(0, 0, 0.95), "normal": normal,
					"height": 0.72 + 0.12 * float(face)})
	# The recovered plain ceiling is prominent from the entry. These broad
	# cutouts hang in two shallow layers above standing and jumping head height.
	# They are sparse enough not to fill the flashlight cone with alpha overdraw.
	for x in [-4.82, -2.45]:
		for z in [-3.48, -1.02, 1.44]:
			sites.append({"origin": Vector3(float(x), 3.07, float(z)),
				"horizontal": Vector3(1.60, 0, 0), "vertical": Vector3(0, 0, 1.50),
				"normal": Vector3.DOWN, "height": 1.50, "ceiling": true})
	for x in [-0.22, 3.92]:
		for z in [-3.48, 1.44]:
			sites.append({"origin": Vector3(float(x), 3.07, float(z)),
				"horizontal": Vector3(1.60, 0, 0), "vertical": Vector3(0, 0, 1.50),
				"normal": Vector3.DOWN, "height": 1.50, "ceiling": true})
	return sites

static func _dense_silk_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in range(_dense_silk_sites().size()):
		var site: Dictionary = _dense_silk_sites()[index]
		var origin: Vector3 = site.origin
		var horizontal: Vector3 = site.horizontal
		var normal: Vector3 = site.normal
		var height: float = site.height
		var vertical: Vector3 = site.get("vertical", Vector3.DOWN * height)
		_append_silk_quad(vertices, normals, uvs, indices, origin,
			horizontal, vertical, normal, index % 2 == 1)
		_append_silk_quad(vertices, normals, uvs, indices,
			origin + normal * (0.05 if site.get("ceiling", false) else 0.26) + Vector3.DOWN * 0.08,
			horizontal * 0.87, vertical * 0.80,
			normal, index % 2 == 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var silk := StandardMaterial3D.new()
	silk.resource_name = "Aged room-spanning spider silk"
	silk.albedo_texture = load(DENSE_SILK_TEXTURE)
	silk.albedo_color = Color(0.61, 0.59, 0.54, 0.84)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	silk.alpha_scissor_threshold = 0.25
	silk.roughness = 1.0
	silk.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, silk)
	return mesh

static func _append_silk_quad(vertices: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array,
		origin: Vector3, horizontal: Vector3, vertical: Vector3,
		normal: Vector3, mirror_uv: bool) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([origin, origin + horizontal,
		origin + vertical, origin + horizontal + vertical]))
	normals.append_array(PackedVector3Array([normal, normal, normal, normal]))
	uvs.append_array(PackedVector2Array([
		Vector2(0.99, 0.02) if mirror_uv else Vector2(0.01, 0.02),
		Vector2(0.01, 0.02) if mirror_uv else Vector2(0.99, 0.02),
		Vector2(0.99, 0.98) if mirror_uv else Vector2(0.01, 0.98),
		Vector2(0.01, 0.98) if mirror_uv else Vector2(0.99, 0.98),
	]))
	_append_facing_quad(indices, base, horizontal, vertical, normal)


static func _append_facing_quad(indices: PackedInt32Array, base: int,
		u: Vector3, v: Vector3, normal: Vector3) -> void:
	# Godot front faces wind clockwise. Match the geometric face to its lighting
	# normal; disabling culling alone still flips a back face's lighting normal.
	if u.cross(v).dot(normal) > 0.0:
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 2, base + 3, base + 1]))
	else:
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 2, base + 1, base + 3]))


static func _append_web_card(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, top_left: Vector3, top_right: Vector3,
		bottom_point: Vector3, facing: Vector3) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([top_left, top_right, bottom_point]))
	var normal := (top_right - top_left).cross(bottom_point - top_left).normalized()
	if normal.dot(facing) < 0.0:
		normal = -normal
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	uvs.append_array(PackedVector2Array([Vector2(0.02, 0.02), Vector2(0.98, 0.02), Vector2(0.5, 0.98)]))
	if (top_right - top_left).cross(bottom_point - top_left).dot(normal) > 0.0:
		indices.append_array(PackedInt32Array([base, base + 2, base + 1]))
	else:
		indices.append_array(PackedInt32Array([base, base + 1, base + 2]))


static func _strand_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		var normal := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
		normals[a] = normal
		normals[b] = normal
		normals[c] = normal
	return normals

static func _append_strand(vertices: PackedVector3Array, indices: PackedInt32Array,
		a: Vector3, b: Vector3, normal: Vector3, width: float) -> void:
	var side: Vector3 = (b - a).cross(normal).normalized() * width * 0.5
	if side.length_squared() < 0.00000001:
		return
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a - side, a + side, b - side, b + side]))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 2, base + 1, base + 3]))
