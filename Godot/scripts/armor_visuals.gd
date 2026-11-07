extends Node3D
## Credited artist garments fitted to Luke. The controller owns visual resources
## only; inventory ownership, mitigation and save data remain in player.gd.

const ARMOR_SCENE_PATH := "res://assets/third_party/makehuman_armor/luke_fitted_armor.glb"
const VARIANTS := {&"shirt": "Shirt", &"pants": "Pants", &"hood": "Hood", &"shoes": "Boots"}
const IDS := {&"shirt": &"leather_shirt", &"pants": &"leather_pants", &"hood": &"leather_hood", &"shoes": &"leather_shoes"}
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _body_original: ArrayMesh
var _garments: Dictionary = {}
var _body_masks: Dictionary = {}
var _body_rest_points: Array = []
var _body_hand_weights: Array = []
var _ready_for_state := false
var _pants_full: ArrayMesh
var _pants_boot_cut: ArrayMesh

func setup(luke_model: Node3D) -> bool:
	if _ready_for_state: return true
	_skeleton = luke_model.get_node_or_null("Model/Skeleton3D") as Skeleton3D
	if _skeleton == null or not ResourceLoader.exists(ARMOR_SCENE_PATH): return false
	for child in _skeleton.get_children():
		if child is MeshInstance3D and child.skin != null:
			_body = child
			break
	if _body == null or not _body.mesh is ArrayMesh: return false
	_body_original = _body.mesh
	var packed := load(ARMOR_SCENE_PATH) as PackedScene
	if packed == null: return false
	var source := packed.instantiate() as Node3D
	add_child(source)
	source.visible = false
	for slot in VARIANTS:
		var source_mesh := source.find_child(VARIANTS[slot], true, false) as MeshInstance3D
		if source_mesh == null or source_mesh.skin == null: continue
		var source_skeleton := source_mesh.get_node_or_null(source_mesh.skeleton) as Skeleton3D
		if source_skeleton == null: continue
		var garment := _rebind(source_mesh, source_skeleton, source)
		if garment == null: continue
		garment.name = "Armor" + VARIANTS[slot]
		_skeleton.add_child(garment)
		garment.skeleton = NodePath("..")
		garment.visible = false
		_garments[slot] = garment
		if slot == &"pants":
			_pants_full = garment.mesh
			_pants_boot_cut = _cut_below(_pants_full, 0.325)
	source.queue_free()
	if _garments.size() != VARIANTS.size():
		for garment in _garments.values(): garment.queue_free()
		_garments.clear()
		return false
	_prepare_body_regions()
	_body_masks[0] = _body_original
	_ready_for_state = true
	return true

func apply_state(state: Dictionary) -> void:
	if not _ready_for_state: return
	var mask := 0
	var bit := 1
	for slot in VARIANTS:
		var equipped: bool = StringName(str(state.get(slot, &""))) == IDS[slot]
		_garments[slot].visible = equipped
		if equipped: mask |= bit
		bit <<= 1
	if not _body_masks.has(mask): _body_masks[mask] = _masked_body(mask)
	_body.mesh = _body_masks[mask]
	_garments[&"pants"].mesh = _pants_boot_cut if (mask & 8) != 0 else _pants_full

func visual_state() -> Dictionary:
	var result := {}
	for slot in _garments: result[slot] = _garments[slot].visible
	return result

func _bind_bone(skin: Skin, bind: int, skeleton: Skeleton3D) -> int:
	var name := skin.get_bind_name(bind)
	return skeleton.find_bone(name) if name != &"" else skin.get_bind_bone(bind)

func _rest_transforms(skin: Skin, skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var bone := _bind_bone(skin, bind, skeleton)
		result.append(skeleton.get_bone_global_rest(bone) * skin.get_bind_pose(bind) if bone >= 0 else Transform3D.IDENTITY)
	return result

func _rest_point(vertex: Vector3, index: int, arrays: Array, transforms: Array[Transform3D]) -> Vector3:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var result := Vector3.ZERO
	for influence in stride:
		var offset := index * stride + influence
		if weights[offset] > 0.0: result += (transforms[bones[offset]] * vertex) * weights[offset]
	return result

func _rest_direction(direction: Vector3, index: int, arrays: Array, transforms: Array[Transform3D]) -> Vector3:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var result := Vector3.ZERO
	for influence in stride:
		var offset := index * stride + influence
		if weights[offset] > 0.0: result += (transforms[bones[offset]].basis.inverse().transposed() * direction) * weights[offset]
	return result.normalized()

func _rebind(source_mesh: MeshInstance3D, source_skeleton: Skeleton3D, source: Node3D) -> MeshInstance3D:
	var new_skin := Skin.new()
	for bind in source_mesh.skin.get_bind_count():
		var source_bone := _bind_bone(source_mesh.skin, bind, source_skeleton)
		if source_bone < 0: return null
		var bone_name := source_skeleton.get_bone_name(source_bone)
		var target_bone := _skeleton.find_bone(bone_name)
		if target_bone < 0: return null
		new_skin.add_named_bind(bone_name, _skeleton.get_bone_global_rest(target_bone).affine_inverse())
	var rest := _rest_transforms(source_mesh.skin, source_skeleton)
	var to_model := source.global_transform.affine_inverse() * source_skeleton.global_transform
	var mesh := ArrayMesh.new()
	for surface in source_mesh.mesh.get_surface_count():
		var arrays := source_mesh.mesh.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in vertices.size():
			vertices[i] = to_model * _rest_point(vertices[i], i, arrays, rest)
			if i < normals.size(): normals[i] = (to_model.basis.inverse().transposed() * _rest_direction(normals[i], i, arrays, rest)).normalized()
			if tangents.size() >= (i+1)*4:
				var t := Vector3(tangents[i*4], tangents[i*4+1], tangents[i*4+2])
				t = (to_model.basis * _rest_direction(t, i, arrays, rest)).normalized()
				tangents[i*4] = t.x
				tangents[i*4+1] = t.y
				tangents[i*4+2] = t.z
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := source_mesh.mesh.surface_get_material(surface)
		if material is StandardMaterial3D: material = _leather_material(material, source_mesh.name)
		mesh.surface_set_material(surface, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.skin = new_skin
	instance.extra_cull_margin = 0.15
	instance.custom_aabb = AABB(Vector3(-1.0,-0.1,-0.6), Vector3(2.0,2.3,1.2))
	return instance

func _leather_material(source: StandardMaterial3D, garment_name: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/third_party/makehuman_armor/leather_adaptation.gdshader")
	material.set_shader_parameter("garment_color", source.albedo_texture)
	material.set_shader_parameter("garment_normal", source.normal_texture)
	var base := "res://assets/third_party/poly_haven/brown_leather/brown_leather_"
	material.set_shader_parameter("leather_color", load("res://assets/generated/aged_field_leather.png"))
	material.set_shader_parameter("leather_tint", Color(.84,.77,.67) if garment_name == "Boots" else Color(1.14,1.06,.94))
	material.set_shader_parameter("leather_normal", load(base+"nor_gl_2k.jpg"))
	material.set_shader_parameter("leather_arm", load(base+"arm_2k.jpg"))
	material.set_shader_parameter("tile_scale", 4.0 if garment_name == "Shirt" else 3.0)
	material.set_shader_parameter("source_normal_strength", 0.35 if garment_name == "Boots" else 0.15)
	return material

func _cut_below(original: ArrayMesh, height: float) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface).duplicate(true)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			if (points[indices[i]].y+points[indices[i+1]].y+points[indices[i+2]].y)/3.0 >= height:
				kept.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
		if kept.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count()-1, original.surface_get_material(surface))
	return result

func _prepare_body_regions() -> void:
	var rest := _rest_transforms(_body.skin, _skeleton)
	for surface in _body_original.get_surface_count():
		var arrays := _body_original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var stride := bones.size() / vertices.size()
		var points := PackedVector3Array()
		var hands := PackedFloat32Array()
		for i in vertices.size():
			var point := _rest_point(vertices[i], i, arrays, rest)
			points.append(point)
			var hand_weight := 0.0
			for influence in stride:
				var offset := i*stride+influence
				var bone := _bind_bone(_body.skin, bones[offset], _skeleton)
				var bone_name := String(_skeleton.get_bone_name(bone))
				if "Hand" in bone_name or "Finger" in bone_name: hand_weight += weights[offset]
			# Luke's authored body atlas places skin hands in its two lower
			# corners. Cuff and palm share bones and height, so cutting by either
			# deletes skin or leaves the old cuff. These existing UV islands give
			# the exact clothing/skin boundary while retaining all hand weights.
			var uv := uvs[i]
			var hand_island := uv.y > 0.825 and (uv.x < 0.25 or uv.x > 0.75)
			hands.append(1.0 if hand_weight > 0.10 and hand_island else 0.0)
		_body_rest_points.append(points)
		_body_hand_weights.append(hands)

func _masked_body(mask: int) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in _body_original.get_surface_count():
		var arrays := _body_original.surface_get_arrays(surface).duplicate(true)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		var points: PackedVector3Array = _body_rest_points[surface]
		var hands: PackedFloat32Array = _body_hand_weights[surface]
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle+1]
			var c := indices[triangle+2]
			var center := (points[a]+points[b]+points[c])/3.0
			var hand := (hands[a]+hands[b]+hands[c])/3.0
			var hide := false
			if surface == 0:
				hide = ((mask & 1) != 0 and center.y > 0.91 and center.y < 1.64 and hand < 0.5)
				# In the A rest pose the palms share the trousers' height, but sit
				# outside the hip/leg width. A height-only pants mask deletes hands.
				hide = hide or ((mask & 2) != 0 and center.y > 0.145 and center.y < 1.035 and absf(center.x) < 0.30)
				hide = hide or ((mask & 8) != 0 and center.y < 0.325)
			elif surface == 2 and (mask & 4) != 0:
				hide = true # The separate opacity surface is Luke's hair cards.
			elif (mask & 4) != 0:
				# Hair/scalp covered by the hood; keep front face, mouth and eyes.
				hide = center.y > 1.76 or (center.y > 1.63 and center.z < -0.018)
			if not hide: kept.append_array(PackedInt32Array([a,b,c]))
		if kept.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count()-1, _body_original.surface_get_material(surface))
	return result
