extends SceneTree
## Validates the actual recovered scene after the reversible dressing pass.

const HouseDressing = preload("res://scripts/house_dressing.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/recovered_house.tscn")
	if scene == null:
		push_error("Recovered house scene failed to load")
		quit(1)
		return
	var house: Node3D = scene.instantiate()
	root.add_child(house)
	var before := house.get_child_count()
	var report: Dictionary = HouseDressing.apply(house)
	var removed: Dictionary = report.removed
	var expected := {
		"SM_Plate_03": 180, "SM_Book_05": 8, "SM_Book_Row_01": 4,
		"SM_Pokerset_Deck": 8, "SM_Cassette": 12,
		"SM_Toothbrush": 5, "SM_Toiletbrush": 5,
		"SM_Utensil_Skimmer": 18, "SM_Soap": 2, "SM_Soap_02": 2,
		"SM_CookingPot_04": 2, "SM_CookingPot_02": 1,
		"SM_Tray_01": 4, "SM_Tray_04": 1, "SM_Breadbox": 1,
		"SM_Trashcan": 7,
	}
	var passed: bool = removed == expected and int(report.removed_total) == 260
	passed = passed and house.get_child_count() == before - 260 + 13
	var webs: MeshInstance3D = house.get_node_or_null("BlackwebCornerWebs")
	passed = passed and webs != null and webs.mesh != null
	if webs != null and webs.mesh != null:
		passed = passed and webs.mesh.get_surface_count() == 1
		passed = passed and webs.mesh.surface_get_array_index_len(0) == 1554
		passed = passed and webs.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var web_bounds: AABB = webs.mesh.get_aabb()
		passed = passed and web_bounds.position.y > 2.30
		passed = passed and web_bounds.position.y + web_bounds.size.y < 3.20
	var radial: MeshInstance3D = house.get_node_or_null("BlackwebRadialWebs")
	passed = passed and radial != null and radial.mesh != null
	if radial != null and radial.mesh != null:
		passed = passed and radial.mesh.get_surface_count() == 1
		passed = passed and radial.mesh.surface_get_array_index_len(0) > 1500
		passed = passed and radial.mesh.surface_get_array_index_len(0) < 15000
		passed = passed and radial.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		passed = passed and radial.get_node_or_null("CollisionShape3D") == null
		var radial_bounds := radial.mesh.get_aabb()
		passed = passed and radial_bounds.position.y > 1.70
		passed = passed and radial_bounds.position.y + radial_bounds.size.y < 3.10
	var hanging: MeshInstance3D = house.get_node_or_null("BlackwebHangingVeils")
	passed = passed and hanging != null and hanging.mesh != null
	if hanging != null and hanging.mesh != null:
		passed = passed and hanging.mesh.get_surface_count() == 1
		passed = passed and hanging.mesh.surface_get_array_index_len(0) > 1000
		passed = passed and hanging.mesh.surface_get_array_index_len(0) < 12000
		passed = passed and hanging.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		passed = passed and hanging.get_node_or_null("CollisionShape3D") == null
		var hanging_bounds := hanging.mesh.get_aabb()
		passed = passed and hanging_bounds.position.y > 1.80
		passed = passed and hanging_bounds.position.y + hanging_bounds.size.y < 3.10
	passed = passed and int(report.radial_webs) == 5 and int(report.hanging_veils) == 5
	var residue: MeshInstance3D = house.get_node_or_null("BlackwebBloodAndGoo")
	passed = passed and residue != null and residue.mesh != null
	if residue != null and residue.mesh != null:
		passed = passed and int(report.residue_decals) == 150
		passed = passed and residue.mesh.get_surface_count() == 3
		passed = passed and HouseDressing._mesh_triangles(residue.mesh) == 300
		var residue_arrays := residue.mesh.surface_get_arrays(0)
		passed = passed and residue_arrays[Mesh.ARRAY_NORMAL].size() == residue_arrays[Mesh.ARRAY_VERTEX].size()
		passed = passed and residue.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		passed = passed and residue.get_node_or_null("CollisionShape3D") == null
		var residue_material := residue.mesh.surface_get_material(0) as StandardMaterial3D
		passed = passed and residue_material != null and residue_material.albedo_texture != null
		if residue_material != null:
			passed = passed and residue_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		for surface in [1, 2]:
			var wet_material := residue.mesh.surface_get_material(surface) as ShaderMaterial
			passed = passed and wet_material != null and wet_material.get_shader_parameter("detail_normal") is Texture2D
	var modeled := house.get_node_or_null("BlackwebModeledSilk")
	passed = passed and modeled != null and int(report.modeled_silk_instances) == 6
	passed = passed and int(report.pbr_orb_cards) == 3
	if modeled != null:
		passed = passed and modeled.find_children("*", "CollisionShape3D", true, false).is_empty()
		passed = passed and modeled.find_children("*", "Light3D", true, false).is_empty()
	var photo_webs: MeshInstance3D = house.get_node_or_null("BlackwebPhotoWebs")
	var dense_silk: MeshInstance3D = house.get_node_or_null("BlackwebDenseSilkCurtains")
	passed = passed and dense_silk != null and int(report.dense_silk_cards) == 112
	if dense_silk != null:
		passed = passed and dense_silk.mesh.surface_get_array_index_len(0) == 672
		passed = passed and dense_silk.mesh.get_aabb().position.y > 1.90
		passed = passed and dense_silk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		passed = passed and dense_silk.get_node_or_null("CollisionShape3D") == null
		var dense_material := dense_silk.mesh.surface_get_material(0) as StandardMaterial3D
		passed = passed and dense_material != null and dense_material.albedo_texture != null
	passed = passed and photo_webs != null and photo_webs.mesh != null
	if photo_webs != null and photo_webs.mesh != null:
		passed = passed and photo_webs.mesh.get_surface_count() == 1
		passed = passed and photo_webs.mesh.surface_get_array_index_len(0) == 42
		passed = passed and photo_webs.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var photo_material := photo_webs.mesh.surface_get_material(0) as StandardMaterial3D
		passed = passed and photo_material != null and photo_material.albedo_texture != null
		if photo_material != null:
			passed = passed and photo_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var accents: MeshInstance3D = house.get_node_or_null("BlackwebSheetAndWrapCards")
	var accent_strands: MeshInstance3D = house.get_node_or_null("BlackwebSheetAndWrapStrands")
	passed = passed and accents != null and accent_strands != null
	if accents != null and accent_strands != null:
		passed = passed and accents.mesh.surface_get_array_index_len(0) == 33
		passed = passed and accent_strands.mesh.surface_get_array_index_len(0) == 462
		passed = passed and accents.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		passed = passed and accent_strands.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cabinet: Node3D = house.get_node_or_null("PaintedWoodenCabinet")
	passed = passed and cabinet != null
	if cabinet != null:
		passed = passed and cabinet.get_node_or_null("FurnitureCollision/CabinetBox") != null
		passed = passed and cabinet.position.distance_to(Vector3(-4.20, 0.40, -3.55)) < 0.01
	var shelf: Node3D = house.get_node_or_null("WornWallShelf")
	passed = passed and shelf != null
	if shelf != null:
		passed = passed and shelf.get_node_or_null("FurnitureCollision/ShelfBox") != null
		passed = passed and shelf.position.distance_to(Vector3(-1.90, 0.40, -3.62)) < 0.01
	var fixture: Node3D = house.get_node_or_null("CagedCeilingFixture")
	passed = passed and fixture != null
	if fixture != null:
		passed = passed and fixture.position.distance_to(Vector3(0.21, 3.04, 0.41)) < 0.01
		passed = passed and fixture.find_children("*", "Light3D", true, false).is_empty()
	for child in house.get_children():
		if str(child.get_meta("ue_mesh_path", "")).contains("SM_Plate_03"):
			passed = false
			break
	print(JSON.stringify({"passed": passed, "removed": removed, "removed_total": report.removed_total,
		"web_fans": report.web_fans, "web_triangles": report.web_triangles,
		"radial_webs": report.radial_webs, "radial_web_triangles": report.radial_web_triangles,
		"hanging_veils": report.hanging_veils, "hanging_veil_triangles": report.hanging_veil_triangles,
		"residue_decals": report.residue_decals, "residue_triangles": report.residue_triangles,
		"residue_generated_atlas": report.residue_generated_atlas,
		"dense_silk_cards": report.dense_silk_cards,
		"photo_web_cards": report.photo_web_cards,
		"ceiling_sheet_cards": report.ceiling_sheet_cards,
		"object_wrap_cards": report.object_wrap_cards,
		"cabinet_count": report.cabinet_count,
		"shelf_count": report.shelf_count,
		"caged_fixture_count": report.caged_fixture_count}))
	house.queue_free()
	quit(0 if passed else 1)
